#if os(iOS)
import SwiftUI
import StackGeometry

/// The one view that re-runs on every scroll tick.
///
/// It stores the consumer's `root` and `children` view values and re-emits them
/// unchanged, so SwiftUI's diff finds identical child structs and skips their
/// bodies. All that actually changes per tick is the layout's resolution and,
/// where a layout uses one, an `Equatable` effect modifier inside each child's
/// own boundary.
struct StackContentLayer<Root: View, Children: View>: View {
    let engine: StackEngine
    let root: Root
    let children: Children

    @Environment(\.layoutDirection) private var layoutDirection

    var body: some View {
        let direction: StackLayoutDirection = layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
        let resolution = engine.resolution

        StackLayoutEngine(engine: engine, resolution: resolution, direction: direction) {
            children

            root
                .environment(\.layoutDirection, layoutDirection)
                .modifier(StackEffectModifier(effect: resolution.root.effect))
                .environment(\.stackRoot, engine.rootState)
                .environment(\.stackItem, engine.rootState)
                .layoutValue(key: StackIsRootValue.self, value: true)
        }
        // The engine resolves leading and trailing itself and solves in
        // physical coordinates, so SwiftUI must not mirror the placement too.
        // The root and each child get the real direction back inside.
        .environment(\.layoutDirection, .leftToRight)
        // Set above every child, so it survives their resolution.
        .environment(\.stackItemEngine, engine)
    }
}
#endif
