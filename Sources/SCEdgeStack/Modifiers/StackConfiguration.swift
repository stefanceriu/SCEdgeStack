#if os(iOS)
import SwiftUI
import StackGeometry

/// How a drag is allowed to start.
public enum StackDragActivation: Equatable, Sendable {
    case anywhere
    /// Only a drag beginning within `width` points of one of `edges`.
    case edges(Set<StackEdge>, width: CGFloat)
}

/// Everything set with a `.stack…` modifier on the container.
public struct StackConfiguration {
    public var layouts: [StackEdge: any StackLayout] = [:]
    public var pagingEnabled = true
    public var continuousNavigationEnabled = false
    public var navigationConstraints: StackNavigationConstraints = .all
    public var animation = StackAnimation()
    public var blocksInteractionWhileAnimating = false
    public var decelerationRate: UIScrollView.DecelerationRate = .fast
    public var dragActivation: StackDragActivation = .anywhere
    public var simultaneousGestures = false

    var onOffsetChange: (@MainActor (CGPoint) -> Void)?
    var onVisibilityChange: (@MainActor (StackItemID, Bool) -> Void)?
    var onStep: (@MainActor (StackItemID, StackNavigationStep) -> Void)?

    public init() {}

    func layout(for edge: StackEdge) -> any StackLayout {
        layouts[edge] ?? PlainStackLayout()
    }
}

extension EnvironmentValues {
    @Entry var stackConfiguration = StackConfiguration()
}

public extension View {
    /// Registers a layout for one edge. Every edge defaults to `PlainStackLayout`.
    func stackLayout(_ layout: any StackLayout, for edge: StackEdge) -> some View {
        transformEnvironment(\.stackConfiguration) { $0.layouts[edge] = layout }
    }

    /// Snap to navigation steps when a drag ends. On by default.
    func stackPagingEnabled(_ enabled: Bool) -> some View {
        transformEnvironment(\.stackConfiguration) { $0.pagingEnabled = enabled }
    }

    /// Let the stack rest anywhere between steps rather than only on them.
    func stackContinuousNavigation(_ enabled: Bool) -> some View {
        transformEnvironment(\.stackConfiguration) { $0.continuousNavigationEnabled = enabled }
    }

    /// Which directions of travel the navigation steps constrain.
    func stackNavigationConstraints(_ constraints: StackNavigationConstraints) -> some View {
        transformEnvironment(\.stackConfiguration) { $0.navigationConstraints = constraints }
    }

    /// The curve and duration used by `StackProxy`.
    func stackAnimation(_ animation: StackAnimation) -> some View {
        transformEnvironment(\.stackConfiguration) { $0.animation = animation }
    }

    /// Ignore programmatic navigation requests while one is already running.
    func stackBlocksInteractionWhileAnimating(_ blocks: Bool) -> some View {
        transformEnvironment(\.stackConfiguration) { $0.blocksInteractionWhileAnimating = blocks }
    }

    func stackDecelerationRate(_ rate: UIScrollView.DecelerationRate) -> some View {
        transformEnvironment(\.stackConfiguration) { $0.decelerationRate = rate }
    }

    /// Restricts where a drag may begin.
    func stackDragActivation(_ activation: StackDragActivation) -> some View {
        transformEnvironment(\.stackConfiguration) { $0.dragActivation = activation }
    }

    /// Let the stack's pan run alongside other gesture recognisers.
    func stackSimultaneousGestures(_ enabled: Bool) -> some View {
        transformEnvironment(\.stackConfiguration) { $0.simultaneousGestures = enabled }
    }

    /// Fires on every scroll tick, synchronously from the resolve pass.
    func onStackOffsetChange(_ action: @escaping @MainActor (CGPoint) -> Void) -> some View {
        transformEnvironment(\.stackConfiguration) { $0.onOffsetChange = action }
    }

    /// Fires only when a child crosses in or out of visibility.
    func onStackVisibilityChange(_ action: @escaping @MainActor (StackItemID, Bool) -> Void) -> some View {
        transformEnvironment(\.stackConfiguration) { $0.onVisibilityChange = action }
    }

    /// Fires when the stack settles on a navigation step.
    func onStackStep(_ action: @escaping @MainActor (StackItemID, StackNavigationStep) -> Void) -> some View {
        transformEnvironment(\.stackConfiguration) { $0.onStep = action }
    }
}
#endif
