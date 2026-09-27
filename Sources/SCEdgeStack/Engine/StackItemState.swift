#if os(iOS)
import SwiftUI
import StackGeometry

/// A stable, observable handle on one child's placement.
///
/// The environment carries the object, never the value, so the environment
/// itself never changes at 120 Hz. Only views that actually read
/// `placement` re-render.
@Observable
@MainActor
public final class StackItemState {
    public let id: StackItemID
    public internal(set) var placement: StackPlacement

    init(id: StackItemID, placement: StackPlacement = StackPlacement()) {
        self.id = id
        self.placement = placement
    }

    public var visibleFraction: Double { placement.visibleFraction }
    public var isVisible: Bool { placement.isVisible }

    /// Observation does not de-duplicate, so the comparison has to happen here.
    func update(_ new: StackPlacement) {
        guard new != placement else { return }
        placement = new
    }
}

extension EnvironmentValues {
    /// The enclosing stacked child's placement, or `nil` outside one.
    @Entry public var stackItem: StackItemState?
    /// The root's placement, available to the root content and its descendants.
    @Entry public var stackRoot: StackItemState?
    /// The ambient safe area, republished because the stack's own geometry
    /// lives in a safe-area-free space.
    @Entry public var stackSafeAreaInsets = EdgeInsets()
}

public extension View {
    /// Applies the stack's republished safe area as padding.
    func stackSafeArea(_ edges: Edge.Set = .all) -> some View {
        modifier(StackSafeAreaModifier(edges: edges))
    }
}

struct StackSafeAreaModifier: ViewModifier {
    @Environment(\.stackSafeAreaInsets) private var insets
    let edges: Edge.Set

    func body(content: Content) -> some View {
        content
            .padding(.top, edges.contains(.top) ? insets.top : 0)
            .padding(.leading, edges.contains(.leading) ? insets.leading : 0)
            .padding(.bottom, edges.contains(.bottom) ? insets.bottom : 0)
            .padding(.trailing, edges.contains(.trailing) ? insets.trailing : 0)
    }
}
#endif
