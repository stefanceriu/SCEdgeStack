#if os(iOS)
import OSLog
import SwiftUI
import StackGeometry

/// One measured, addressed child.
struct StackItemDescriptor: Equatable {
    var key: StackItemKey
    var token: StackItemToken
    var id: StackItemID
    var size: CGSize
    var steps: [StackNavigationStep]
}

/// The solve loop. The only hot observed property is `resolution`.
@Observable
@MainActor
final class StackEngine {

    /// Written once per scroll tick; drives exactly one view body.
    private(set) var resolution = StackResolution()

    @ObservationIgnored private(set) var spec = StackSpec(containerSize: .zero)
    @ObservationIgnored var configuration = StackConfiguration() {
        didSet {
            // Each edge's layout is captured into the spec, so a new one needs
            // the spec rebuilt -- measurements alone would never notice.
            let fingerprint = Self.fingerprint(configuration.layouts)
            guard fingerprint != layoutFingerprint else { return }
            layoutFingerprint = fingerprint
            if !descriptors.isEmpty { rebuildSpec(containerSize: spec.containerSize) }
        }
    }
    @ObservationIgnored private var layoutFingerprint: [String] = []
    @ObservationIgnored var layoutDirection = StackLayoutDirection.leftToRight
    @ObservationIgnored weak var scrollController: StackScrollCoordinator?

    /// Keyed by child, not position, so a state follows its child through a
    /// reorder.
    @ObservationIgnored private var states: [StackItemID: StackItemState] = [:]
    /// By child rather than position, so a re-measure does not re-announce
    /// children that stayed visible, and a removed child is still announced.
    @ObservationIgnored private var visibleIDs: Set<StackItemID> = []
    @ObservationIgnored private var ids: [StackItemKey: StackItemID] = [:]
    @ObservationIgnored private var keys: [StackItemID: StackItemKey] = [:]
    @ObservationIgnored private var keysByToken: [StackItemToken: StackItemKey] = [:]
    @ObservationIgnored private var descriptors: [StackItemDescriptor] = []
    @ObservationIgnored private var activeEdge: StackPhysicalEdge?
    @ObservationIgnored private var isResolving = false

    @ObservationIgnored let rootState = StackItemState(
        id: .root, placement: StackPlacement(visibleFraction: 1, isVisible: true)
    )

    static let log = Logger(subsystem: "com.stefanceriu.SCEdgeStack", category: "stack")

    var containerSize: CGSize { spec.containerSize }

    // MARK: - Solving

    /// Solves for `offset` and publishes the result. Called once per tick from
    /// `scrollViewDidScroll`.
    func apply(offset: CGPoint) {
        guard !isResolving else { return }
        guard offset != resolution.contentOffset || resolution.items.count != descriptors.count else { return }
        isResolving = true
        defer { isResolving = false }

        let solved = StackOcclusionSolver.resolve(
            spec: spec, contentOffset: offset, previousActiveEdge: activeEdge
        )
        activeEdge = StackOcclusionSolver.activeEdge(for: offset) ?? activeEdge

        if solved != resolution { resolution = solved }

        for descriptor in descriptors {
            guard let placement = solved.items[descriptor.key] else { continue }
            state(for: descriptor.key).update(placement)
        }
        rootState.update(solved.root)

        configuration.onOffsetChange?(offset)

        let nowVisible = Set(solved.visibleItems.map(id(for:)))
        if let report = configuration.onVisibilityChange {
            for id in nowVisible.subtracting(visibleIDs) { report(id, true) }
            for id in visibleIDs.subtracting(nowVisible) { report(id, false) }
        }
        visibleIDs = nowVisible
    }

    /// Re-solves at the current offset, after the spec changed underneath us.
    func resolveAgain() {
        let offset = resolution.contentOffset
        resolution = StackResolution()
        apply(offset: offset)
    }

    // MARK: - Measurement

    /// Called from a coalesced task, never from inside the layout pass.
    func commitMeasurements(containerSize: CGSize, descriptors: [StackItemDescriptor]) {
        guard containerSize != spec.containerSize || descriptors != self.descriptors else { return }
        self.descriptors = descriptors
        rebuildSpec(containerSize: containerSize)
    }

    private func rebuildSpec(containerSize: CGSize) {
        var edges: [StackPhysicalEdge: StackEdgeSpec] = [:]
        for descriptor in descriptors.sorted(by: { $0.key < $1.key }) {
            let edge = descriptor.key.edge
            var edgeSpec = edges[edge] ?? StackEdgeSpec(items: [], layout: layout(for: edge))
            edgeSpec.items.append(StackItemSpec(size: descriptor.size, steps: descriptor.steps))
            edges[edge] = edgeSpec
        }

        ids = Dictionary(uniqueKeysWithValues: descriptors.map { ($0.key, $0.id) })
        keysByToken = Dictionary(descriptors.map { ($0.token, $0.key) }, uniquingKeysWith: { first, _ in first })
        keys = Dictionary(descriptors.map { ($0.id, $0.key) }, uniquingKeysWith: { first, _ in first })
        states = states.filter { keys[$0.key] != nil }

        spec = StackSpec(containerSize: containerSize, edges: edges)
        diagnoseAxes()

        resolveAgain()
        scrollController?.specChanged()
    }

    /// Layouts are plain values, so their reflection identifies them, parameters
    /// included.
    private static func fingerprint(_ layouts: [StackEdge: any StackLayout]) -> [String] {
        layouts.map { "\($0.key)=\(String(reflecting: $0.value))" }.sorted()
    }

    private func layout(for physical: StackPhysicalEdge) -> any StackLayout {
        // The declarative edge that resolves to this physical one owns the layout.
        for edge in StackEdge.allCases where edge.resolved(layoutDirection) == physical {
            if let layout = configuration.layouts[edge] { return layout }
        }
        return PlainStackLayout()
    }

    /// Logs a fault when children sit on both axes, where occlusion is undefined.
    private func diagnoseAxes() {
        let vertical = !spec.items(at: .top).isEmpty || !spec.items(at: .bottom).isEmpty
        let horizontal = !spec.items(at: .left).isEmpty || !spec.items(at: .right).isEmpty
        guard vertical && horizontal else { return }
        Self.log.fault("""
            SCEdgeStack has children on both the vertical and the horizontal axis. \
            Only one axis can be navigated at a time and the occlusion of the other \
            is undefined. Split them across two nested stacks.
            """)
    }

    // MARK: - Addressing

    func state(for key: StackItemKey) -> StackItemState {
        let id = id(for: key)
        if let existing = states[id] { return existing }
        let created = StackItemState(id: id)
        states[id] = created
        return created
    }

    func id(for key: StackItemKey) -> StackItemID {
        ids[key] ?? .position(declarative(key.edge), key.index)
    }

    func key(forToken token: StackItemToken) -> StackItemKey? {
        keysByToken[token]
    }

    func key(for id: StackItemID) -> StackItemKey? {
        if let key = keys[id] { return key }
        guard case let .position(edge, index) = id.storage else { return nil }
        return StackItemKey(edge: edge.resolved(layoutDirection), index: index)
    }

    func steps(for key: StackItemKey) -> [StackNavigationStep] {
        descriptors.first { $0.key == key }?.steps ?? []
    }

    private func declarative(_ physical: StackPhysicalEdge) -> StackEdge {
        StackEdge.allCases.first { $0.resolved(layoutDirection) == physical } ?? .top
    }

    // MARK: - Insets

    func insets(for regime: StackInsetRegime) -> StackInsetResolution {
        StackInsetSolver.resolve(
            spec: spec, regime: regime, constraints: configuration.navigationConstraints
        )
    }

    /// The regime that brackets where the stack is right now.
    var liveRegime: StackInsetRegime {
        configuration.continuousNavigationEnabled
            ? .unconstrained
            : .live(contentOffset: resolution.contentOffset, anchor: resolution.anchor)
    }

    /// The offset at which `key` sits at `step`.
    func offset(for key: StackItemKey, at step: StackNavigationStep) -> CGPoint? {
        guard let edgeSpec = spec.edges[key.edge], key.index < edgeSpec.items.count else { return nil }
        let value = StackStepSolver.offset(
            fraction: step.fraction,
            edge: key.edge,
            reversed: edgeSpec.isReversed,
            finalFrame: spec.finalFrames(at: key.edge)[key.index],
            maximumInset: spec.maximumInset(at: key.edge),
            containerSize: spec.containerSize
        )
        return key.edge.axis.point(value.rounded())
    }
}
#endif
