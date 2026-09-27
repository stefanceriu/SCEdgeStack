#if os(iOS)
import SwiftUI
import StackGeometry

/// Gives the enclosed content a `StackProxy` for the `EdgeStack` inside it,
/// mirroring `ScrollViewReader`.
@MainActor
public struct StackReader<Content: View>: View {
    @State private var engine = StackEngine()
    private let content: (StackProxy) -> Content

    public init(@ViewBuilder content: @escaping (StackProxy) -> Content) {
        self.content = content
    }

    public var body: some View {
        content(StackProxy(engine: engine))
            .environment(\.stackEngineProvider, engine)
    }
}

/// Imperative control over a stack.
///
/// Deliberately a proxy rather than a `Binding<StackPosition?>`: the source of
/// truth is a content offset varying at 120 Hz under the finger, and a two-way
/// binding would either fight the gesture or quantise to discrete steps --
/// which is exactly what continuous navigation forbids.
///
/// Reading `contentOffset` or `visibleItems` from a view body subscribes that
/// body to every scroll tick. That is the price of asking.
@MainActor
public struct StackProxy {
    let engine: StackEngine

    init(engine: StackEngine) {
        self.engine = engine
    }

    public var contentOffset: CGPoint {
        engine.resolution.contentOffset
    }

    public var visibleItems: [StackItemID] {
        engine.resolution.visibleItems.map { engine.id(for: $0) }
    }

    public func placement(for id: StackItemID) -> StackPlacement? {
        guard let key = engine.key(for: id) else { return nil }
        return engine.resolution.items[key]
    }

    /// Unfolds `id` to `step`.
    ///
    /// Adding the view to the `children` builder is the push; this is the
    /// unfold. Cancelling the surrounding task stops the animation in flight.
    @discardableResult
    public func reveal(
        _ id: StackItemID,
        to step: StackNavigationStep = .full,
        animation: StackAnimation? = nil
    ) async -> Bool {
        guard let key = engine.key(for: id),
              let offset = engine.offset(for: key, at: step),
              let controller = engine.scrollController else { return false }
        return await controller.navigate(
            to: offset, step: step, animation: animation ?? engine.configuration.animation
        )
    }

    @discardableResult
    public func reveal(
        _ id: some Hashable & Sendable,
        to step: StackNavigationStep = .full,
        animation: StackAnimation? = nil
    ) async -> Bool {
        await reveal(StackItemID(id), to: step, animation: animation)
    }

    /// Returns the stack to the root. Removing the view from the `children`
    /// builder afterwards is the pop.
    @discardableResult
    public func fold(animation: StackAnimation? = nil) async -> Bool {
        guard let controller = engine.scrollController else { return false }
        return await controller.navigate(
            to: .zero, step: .folded, animation: animation ?? engine.configuration.animation
        )
    }

    public func stopAnimation() {
        engine.scrollController?.stopAnimation()
    }
}
#endif
