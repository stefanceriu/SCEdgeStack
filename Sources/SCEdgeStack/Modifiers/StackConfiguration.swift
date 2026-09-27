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
    public var decelerationRate: UIScrollView.DecelerationRate = .fast
    public var dragActivation: StackDragActivation = .anywhere
    public var simultaneousGestures = false

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
}
#endif
