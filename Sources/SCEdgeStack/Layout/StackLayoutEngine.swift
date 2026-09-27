#if os(iOS)
import SwiftUI
import StackGeometry

struct StackIsRootValue: LayoutValueKey {
    static let defaultValue = false
}

/// Places every child from the already-solved resolution.
///
/// A `Layout` rather than a `ZStack` of offsets: this is the only SwiftUI API
/// that gives synchronous access to a child's ideal size, and the inset maths
/// needs every child's extent *before* anything is placed. Preference-key
/// measurement lands a frame late, and a stale `contentInset` on a 120 Hz drag
/// is a visible hitch at every navigation step.
struct StackLayoutEngine: Layout {
    let engine: StackEngine
    /// Stored, not read from the engine, so a changed resolution invalidates
    /// the layout through SwiftUI's own diff.
    let resolution: StackResolution
    let direction: StackLayoutDirection

    struct Cache {
        var containerSize: CGSize = .zero
        var descriptors: [StackItemDescriptor] = []
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    /// Kept across passes. The default rebuilds the cache whenever the layout
    /// changes -- every scroll tick, since `resolution` is stored -- and each
    /// rebuild would queue a redundant measurement commit.
    func updateCache(_ cache: inout Cache, subviews: Subviews) {}

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let container = proposal.replacingUnspecifiedDimensions()
        guard container.width > 0, container.height > 0 else { return container }

        var counts: [StackPhysicalEdge: Int] = [:]
        var descriptors: [StackItemDescriptor] = []

        // Declaration order decides the address: index 0 sits adjacent to the root.
        for subview in subviews {
            guard let token = subview[StackTokenValue.self],
                  let declared = subview[StackEdgeValue.self] else { continue }

            let edge = declared.resolved(direction)
            let index = counts[edge, default: 0]
            counts[edge] = index + 1

            descriptors.append(
                StackItemDescriptor(
                    key: StackItemKey(edge: edge, index: index),
                    token: token,
                    id: subview[StackIDValue.self] ?? .position(declared, index),
                    size: measure(
                        subview, on: edge,
                        extent: subview[StackExtentValue.self], container: container
                    ),
                    steps: subview[StackStepsValue.self]
                )
            )
        }

        // Measurement flows layout -> engine, so it never happens inline: a
        // difference enqueues one coalesced commit instead.
        if container != cache.containerSize || descriptors != cache.descriptors {
            cache.containerSize = container
            cache.descriptors = descriptors
            let engine = engine
            Task { @MainActor in
                engine.commitMeasurements(containerSize: container, descriptors: descriptors)
            }
        }

        return container
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        // Frames are solved in scroll-content space; the host view is pinned to
        // the viewport, so they come back by the content offset.
        let origin = CGPoint(
            x: bounds.minX - resolution.contentOffset.x,
            y: bounds.minY - resolution.contentOffset.y
        )
        let rootFrame = resolution.root.frame == .zero
            ? CGRect(origin: .zero, size: bounds.size)
            : resolution.root.frame

        for subview in subviews {
            let frame: CGRect
            if let token = subview[StackTokenValue.self] {
                let key = cache.descriptors.first { $0.token == token }?.key
                frame = key.flatMap { resolution.items[$0]?.frame }
                    ?? offscreenFrame(token, bounds: bounds, cache: cache)
            } else {
                // The root, or a child that forgot `.stackEdge(_:)`.
                frame = rootFrame
            }
            subview.place(
                at: CGPoint(x: origin.x + frame.minX, y: origin.y + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func measure(
        _ subview: LayoutSubview,
        on edge: StackPhysicalEdge,
        extent: CGFloat?,
        container: CGSize
    ) -> CGSize {
        switch edge.axis {
        case .horizontal:
            let width = extent ?? subview.sizeThatFits(
                ProposedViewSize(width: nil, height: container.height)
            ).width
            return CGSize(width: width, height: container.height)
        case .vertical:
            let height = extent ?? subview.sizeThatFits(
                ProposedViewSize(width: container.width, height: nil)
            ).height
            return CGSize(width: container.width, height: height)
        }
    }

    /// Where a child that has been measured but not yet solved goes: just
    /// outside its edge, for the one frame before the commit lands.
    private func offscreenFrame(_ token: StackItemToken, bounds: CGRect, cache: Cache) -> CGRect {
        guard let descriptor = cache.descriptors.first(where: { $0.token == token }) else {
            return CGRect(origin: .zero, size: .zero)
        }
        let size = descriptor.size
        return switch descriptor.key.edge {
        case .top: CGRect(x: 0, y: -size.height, width: size.width, height: size.height)
        case .left: CGRect(x: -size.width, y: 0, width: size.width, height: size.height)
        case .bottom: CGRect(x: 0, y: bounds.height, width: size.width, height: size.height)
        case .right: CGRect(x: bounds.width, y: 0, width: size.width, height: size.height)
        }
    }
}
#endif
