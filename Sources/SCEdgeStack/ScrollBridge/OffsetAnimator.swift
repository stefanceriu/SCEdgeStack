#if os(iOS)
import QuartzCore
import UIKit
import StackGeometry

/// Drives `UIScrollView.contentOffset` along an arbitrary easing curve.
///
/// SwiftUI has no way to do this: `UnitCurve` is a cubic Bezier and cannot
/// express elastic or bounce, and its animation system cannot own a UIKit
/// property.
@MainActor
final class OffsetAnimator {

    /// Breaks the retain cycle `CADisplayLink` would otherwise create with its
    /// target, and cleans the link up if the animator goes away underneath it.
    @MainActor
    private final class DisplayLinkProxy: NSObject {
        weak var animator: OffsetAnimator?

        @objc func tick(_ link: CADisplayLink) {
            guard let animator else { return link.invalidate() }
            animator.tick(link)
        }
    }

    private var link: CADisplayLink?
    private weak var scrollView: UIScrollView?
    private var easing = StackEasing.linear
    private var duration: TimeInterval = 0
    private var startTime: CFTimeInterval = 0
    private var startOffset = CGPoint.zero
    private var delta = CGPoint.zero
    private var continuation: CheckedContinuation<Bool, Never>?

    var isAnimating: Bool { link.map { !$0.isPaused } ?? false }


    /// Returns `true` if the animation ran to completion, `false` if it was
    /// stopped or cancelled.
    func animate(
        _ scrollView: UIScrollView,
        to target: CGPoint,
        easing: StackEasing,
        duration: TimeInterval
    ) async -> Bool {
        stop(finished: false)

        // Zero-duration and no-op fast path: it is what makes an unanimated
        // navigation synchronous.
        if duration <= 0 || scrollView.contentOffset == target {
            scrollView.contentOffset = target
            return true
        }

        self.scrollView = scrollView
        self.easing = easing
        self.duration = duration
        startTime = 0
        delta = CGPoint(
            x: target.x - scrollView.contentOffset.x,
            y: target.y - scrollView.contentOffset.y
        )

        let proxy = DisplayLinkProxy()
        proxy.animator = self
        let link = CADisplayLink(target: proxy, selector: #selector(DisplayLinkProxy.tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.isPaused = true
        link.add(to: .main, forMode: .common)
        self.link = link

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
                link.isPaused = false
            }
        } onCancel: {
            Task { @MainActor in self.stop(finished: false) }
        }
    }

    func stop(finished: Bool = false) {
        guard let link, !link.isPaused else { return }
        link.isPaused = true
        link.invalidate()
        self.link = nil
        continuation?.resume(returning: finished)
        continuation = nil
    }

    private func tick(_ link: CADisplayLink) {
        guard let scrollView else { return stop(finished: false) }

        if startTime == 0 {
            startTime = link.timestamp
            startOffset = scrollView.contentOffset
            return
        }

        var ratio = (link.timestamp - startTime) / duration
        // The final-tick snap: without it the last frame lands short.
        ratio = (1 - ratio < 0.01) ? 1 : easing(ratio)

        scrollView.contentOffset = CGPoint(
            x: startOffset.x + delta.x * ratio,
            y: startOffset.y + delta.y * ratio
        )

        if ratio == 1 { stop(finished: true) }
    }
}
#endif
