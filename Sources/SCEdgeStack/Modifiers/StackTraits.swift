#if os(iOS)
import SwiftUI
import StackGeometry

/// A stable per-declaration identity, handed to the layout so it can tell the
/// engine which child ended up where.
struct StackItemToken: Hashable, Sendable {
    let id = UUID()
}

struct StackTokenValue: LayoutValueKey {
    static let defaultValue: StackItemToken? = nil
}

struct StackEdgeValue: LayoutValueKey {
    static let defaultValue: StackEdge? = nil
}

struct StackIDValue: LayoutValueKey {
    static let defaultValue: StackItemID? = nil
}

struct StackStepsValue: LayoutValueKey {
    static let defaultValue: [StackNavigationStep] = []
}

struct StackExtentValue: LayoutValueKey {
    static let defaultValue: CGFloat? = nil
}

public extension View {
    /// Declares which edge of the root this child stacks off.
    ///
    /// Without it the view is not a stacked child at all, and it must come
    /// **first**: it wraps the view, so any other `.stack…` trait applied
    /// before it is swallowed.
    func stackEdge(_ edge: StackEdge) -> some View {
        StackItemBoundary(edge: edge) { self }
            .layoutValue(key: StackEdgeValue.self, value: edge)
    }

    /// Overrides the default `.position(edge, index)` address.
    func stackID(_ id: some Hashable & Sendable) -> some View {
        layoutValue(key: StackIDValue.self, value: StackItemID(id))
    }

    /// Overload so an already-made `StackItemID` is not wrapped in another one.
    func stackID(_ id: StackItemID) -> some View {
        layoutValue(key: StackIDValue.self, value: id)
    }

    /// Positions at which the stack stops while revealing this child.
    /// `0` and `1` are always present.
    func stackNavigationSteps(_ steps: [StackNavigationStep]) -> some View {
        layoutValue(key: StackStepsValue.self, value: steps)
    }

    /// Fixes this child's extent along its edge's axis, skipping measurement.
    /// The documented escape hatch when measurement churn is a problem.
    func stackExtent(_ extent: CGFloat) -> some View {
        layoutValue(key: StackExtentValue.self, value: extent)
    }
}

/// Wraps one stacked child.
///
/// It exists because a child's environment and accessibility are resolved
/// before a container ever sees it. Injecting them from the outside -- which is
/// what `Group(subviews:)` invites -- silently does nothing. From in here, one
/// level inside the child's own subtree, they land.
struct StackItemBoundary<Content: View>: View {
    let edge: StackEdge
    @ViewBuilder var content: Content

    @Environment(\.stackItemEngine) private var engine
    @State private var token = StackItemToken()

    var body: some View {
        // Read the resolution unconditionally: reading it only when a key
        // already exists would register no observation on the first pass, and
        // the boundary would never learn that it has one.
        let resolution = engine?.resolution
        let key = engine?.key(forToken: token)
        let placement = key.flatMap { resolution?.items[$0] }
        let aboveRoot = engine?.configuration.layout(for: edge).stacksAboveRoot ?? false

        content
            .environment(\.layoutDirection, engine?.layoutDirection == .rightToLeft ? .rightToLeft : .leftToRight)
            .modifier(StackEffectModifier(effect: placement?.effect ?? .identity))
            .layoutValue(key: StackTokenValue.self, value: token)
            // Children draw under the root unless their layout stacks above it.
            .zIndex(aboveRoot ? 1 : -1)
    }
}
#endif
