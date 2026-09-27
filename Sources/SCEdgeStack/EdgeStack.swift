#if os(iOS)
import SwiftUI
import StackGeometry

extension EnvironmentValues {
    /// Hands a `StackReader`'s engine to the `EdgeStack` inside it.
    @Entry var stackEngineProvider: StackEngine?
    /// Hands a stack's engine to its own children, and to nothing nested deeper.
    @Entry var stackItemEngine: StackEngine?
}

/// A container that stacks children off the edges of a root view.
///
/// ```swift
/// EdgeStack {
///     MapView()
/// } children: {
///     MenuView()
///         .stackEdge(.leading)
///         .stackID(Panel.menu)
/// }
/// .stackLayout(ParallaxStackLayout(), for: .leading)
/// ```
///
/// Order within an edge is declaration order; index 0 sits adjacent to the root.
@MainActor
public struct EdgeStack<Root: View, Children: View>: View {

    private let root: Root
    private let children: Children

    @Environment(\.stackConfiguration) private var configuration
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.stackEngineProvider) private var provided

    @State private var owned = StackEngine()

    public init(
        @ViewBuilder content: () -> Root,
        @ViewBuilder children: () -> Children
    ) {
        self.root = content()
        self.children = children()
    }

    public init(@ViewBuilder content: () -> Root) where Children == EmptyView {
        self.root = content()
        self.children = EmptyView()
    }

    public var body: some View {
        let engine = provided ?? owned
        let direction: StackLayoutDirection = layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight

        // The stack's geometry lives in a safe-area-free space, so the host
        // ignores the safe area -- but the ambient insets are read here, one
        // level up where they are still visible, and republished to children.
        GeometryReader { proxy in
            StackScrollHost(
                engine: engine,
                configuration: configuration,
                layoutDirection: direction,
                content: StackContentLayer(engine: engine, root: root, children: children)
                    .environment(\.stackSafeAreaInsets, proxy.safeAreaInsets)
                    .environment(\.layoutDirection, layoutDirection)
            )
            .ignoresSafeArea()
        }
    }
}
#endif
