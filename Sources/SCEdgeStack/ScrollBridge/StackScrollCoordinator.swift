#if os(iOS)
import UIKit
import StackGeometry

/// The only object that touches the scroll view.
///
/// It is the sole owner of `contentInset`, which it applies with the delegate
/// detached and the offset restored -- and **never** while tracking or
/// decelerating: mid-drag inset mutation leaves the scroll stuck between pages.
@MainActor
final class StackScrollCoordinator: NSObject, UIScrollViewDelegate {

    /// Finite, so UIKit cannot clamp the offset while the stack re-measures.
    /// `CGFLOAT_MAX` would make it clamp to nonsense.
    private static let sentinelInset = CGFloat.greatestFiniteMagnitude / 4

    let engine: StackEngine

    weak var scrollView: PassthroughScrollView?
    var hostingController: UIViewController?

    private var appliedInsets: StackInsets?
    private var restoreTarget: (key: StackItemKey, fraction: Double)?

    init(engine: StackEngine) {
        self.engine = engine
        super.init()
        engine.scrollController = self
    }

    // MARK: - Insets

    /// The regime the stack should be in right now.
    private var regime: StackInsetRegime {
        engine.liveRegime
    }

    private func updateInsets() {
        guard let scrollView else { return }
        guard !scrollView.isTracking, !scrollView.isDecelerating else { return }
        apply(engine.insets(for: regime).insets)
    }

    private func apply(_ insets: StackInsets) {
        guard let scrollView, insets != appliedInsets else { return }
        appliedInsets = insets

        let delegate = scrollView.delegate
        scrollView.delegate = nil
        let offset = scrollView.contentOffset
        scrollView.contentInset = UIEdgeInsets(
            top: insets.top, left: insets.left, bottom: insets.bottom, right: insets.right
        )
        scrollView.contentOffset = offset
        scrollView.contentSize = scrollView.bounds.size
        scrollView.delegate = delegate
    }

    private func setOffset(_ offset: CGPoint) {
        guard let scrollView else { return }
        let delegate = scrollView.delegate
        scrollView.delegate = nil
        scrollView.contentOffset = offset
        scrollView.delegate = delegate
        engine.apply(offset: offset)
    }

    // MARK: - Lifecycle

    /// The measured stack changed: re-apply the scroll range, and restore the
    /// anchored position if this was a rotation.
    func specChanged() {
        if let restoreTarget {
            self.restoreTarget = nil
            if let offset = engine.offset(for: restoreTarget.key, at: StackNavigationStep(restoreTarget.fraction)) {
                setOffset(offset)
            }
        }
        clampIntoRange()
        appliedInsets = nil
        updateInsets()
    }

    /// Setting a smaller inset does not move the offset, so a stack whose
    /// unfolded child was removed would rest beyond its own range.
    private func clampIntoRange() {
        guard let scrollView, !scrollView.isTracking else { return }
        let range = engine.insets(for: .unconstrained).insets
        let offset = scrollView.contentOffset
        let clamped = CGPoint(
            x: min(max(offset.x, -range.left), range.right),
            y: min(max(offset.y, -range.top), range.bottom)
        )
        if clamped != offset { setOffset(clamped) }
    }

    /// Handles rotation and any other size change. Widening the
    /// insets first is what stops UIKit clamping the offset mid-re-measure.
    func boundsSizeChanged(_ size: CGSize) {
        guard let scrollView else { return }
        if let anchor = engine.resolution.anchor {
            restoreTarget = (anchor, engine.resolution.items[anchor]?.visibleFraction ?? 0)
        }
        let delegate = scrollView.delegate
        scrollView.delegate = nil
        scrollView.contentInset = UIEdgeInsets(
            top: Self.sentinelInset, left: Self.sentinelInset,
            bottom: Self.sentinelInset, right: Self.sentinelInset
        )
        scrollView.delegate = delegate
        appliedInsets = nil
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        engine.apply(offset: scrollView.contentOffset)
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        // Bouncing past the insets collapses the reported velocity to almost
        // nothing, so pagination has to give way to a straight clamp.
        if let clamped = StackPaginationSolver.bounceClamp(
            contentOffset: scrollView.contentOffset,
            insets: appliedInsets ?? .zero,
            target: targetContentOffset.pointee
        ) {
            targetContentOffset.pointee = clamped
            return
        }

        guard let adjusted = StackPaginationSolver.adjustedTarget(
            spec: engine.spec,
            target: targetContentOffset.pointee,
            velocity: velocity,
            pagingEnabled: engine.configuration.pagingEnabled
        ) else { return }

        targetContentOffset.pointee = adjusted.offset
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else { return }
        settle()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        settle()
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        settle()
    }

    private func settle() {
        updateInsets()
    }
}
#endif
