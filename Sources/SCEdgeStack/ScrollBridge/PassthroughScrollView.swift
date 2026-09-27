#if os(iOS)
import UIKit
import StackGeometry

/// The physics and gesture engine. Never exposed.
///
/// `contentSize == bounds.size` always: the entire scroll range is
/// `contentInset`. That is load-bearing, and it is why
/// `contentInsetAdjustmentBehavior` must be `.never` -- any UIKit
/// inset adjustment corrupts the range, because the range *is* the inset.
final class PassthroughScrollView: UIScrollView {

    /// The hosting controller's view, pinned to the viewport so the SwiftUI
    /// subtree stays put while the offset moves underneath it.
    weak var contentHost: UIView?

    var onBoundsSizeChange: ((CGSize) -> Void)?
    var dragActivation: StackDragActivation = .anywhere
    var allowsSimultaneousGestures = false

    private var lastBoundsSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentInsetAdjustmentBehavior = .never
        isDirectionalLockEnabled = true
        decelerationRate = .fast
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        delaysContentTouches = false
        // Overrides whatever _adjustContentOffsetIfNecessary might have done.
        contentOffset = .zero
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not available") }

    override func layoutSubviews() {
        super.layoutSubviews()

        contentHost?.frame = bounds
        contentSize = bounds.size

        if bounds.size != lastBoundsSize {
            lastBoundsSize = bounds.size
            onBoundsSizeChange?(bounds.size)
        }
    }

    /// Suppresses UIKit scrolling us to a focused text field: a `TextField` in
    /// a child would otherwise make UIKit scroll a zero-content scroll view and
    /// destroy the offset.
    override func scrollRectToVisible(_ rect: CGRect, animated: Bool) {
        guard !hasTextInputFirstResponder else { return }
        super.scrollRectToVisible(rect, animated: animated)
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return super.gestureRecognizerShouldBegin(gestureRecognizer)
        }
        return allowsDrag(from: pan.location(in: self), velocity: pan.velocity(in: self))
            && super.gestureRecognizerShouldBegin(gestureRecognizer)
    }

    /// Whether a drag starting at `point` (in scroll-view coordinates) with
    /// `velocity` may move the stack.
    ///
    /// Edge activation only gates opening from rest: once anything is
    /// unfolded, a drag from anywhere can move it, or nothing could close.
    func allowsDrag(from point: CGPoint, velocity: CGPoint) -> Bool {
        guard case let .edges(edges, width) = dragActivation, contentOffset == .zero else { return true }

        for edge in edges {
            let physical = edge.resolved(
                effectiveUserInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
            )
            let withinBand = switch physical {
            case .top: point.y <= width
            case .left: point.x <= width
            case .bottom: point.y >= bounds.height - width
            case .right: point.x >= bounds.width - width
            }
            // Travelling away from the edge means unfolding the child there.
            let travelling = physical.axis.component(of: velocity) * -physical.unfoldingSign > 0
            if withinBand && travelling { return true }
        }

        return false
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        allowsSimultaneousGestures
    }

    private var hasTextInputFirstResponder: Bool {
        func firstResponder(in view: UIView) -> UIView? {
            if view.isFirstResponder { return view }
            for subview in view.subviews {
                if let found = firstResponder(in: subview) { return found }
            }
            return nil
        }
        return firstResponder(in: self) is UITextInput
    }
}
#endif
