#if os(iOS)
import Testing
import SwiftUI
import UIKit
@testable import SCEdgeStack

@MainActor
@Suite("Offset animator")
struct OffsetAnimatorTests {

    private func scrollView() -> UIScrollView {
        let view = UIScrollView(frame: CGRect(x: 0, y: 0, width: 375, height: 812))
        view.contentInset = UIEdgeInsets(top: 400, left: 400, bottom: 400, right: 400)
        return view
    }

    @Test func aZeroDurationJumpIsSynchronous() async {
        let animator = OffsetAnimator()
        let view = scrollView()
        let finished = await animator.animate(
            view, to: CGPoint(x: -200, y: 0), easing: .linear, duration: 0
        )
        #expect(finished)
        #expect(view.contentOffset == CGPoint(x: -200, y: 0))
    }

    @Test func alreadyThereFinishesImmediately() async {
        let animator = OffsetAnimator()
        let view = scrollView()
        view.contentOffset = CGPoint(x: -200, y: 0)
        #expect(await animator.animate(view, to: CGPoint(x: -200, y: 0), easing: .elasticOut, duration: 1))
    }

    @Test func itLandsExactlyOnTheTarget() async {
        let animator = OffsetAnimator()
        let view = scrollView()
        let finished = await animator.animate(
            view, to: CGPoint(x: -200, y: 0), easing: .elasticOut, duration: 0.2
        )
        #expect(finished)
        #expect(abs(view.contentOffset.x + 200) < 0.001)
        #expect(!animator.isAnimating)
    }

    @Test func cancellingTheTaskStopsItMidFlight() async {
        let animator = OffsetAnimator()
        let view = scrollView()

        let task = Task { @MainActor in
            await animator.animate(view, to: CGPoint(x: -400, y: 0), easing: .linear, duration: 5)
        }
        try? await Task.sleep(for: .milliseconds(120))
        #expect(animator.isAnimating)

        task.cancel()
        let finished = await task.value
        #expect(!finished)
        #expect(!animator.isAnimating)
        #expect(view.contentOffset.x > -400)
    }

    @Test func stoppingReportsUnfinished() async {
        let animator = OffsetAnimator()
        let view = scrollView()

        async let run = animator.animate(view, to: CGPoint(x: -400, y: 0), easing: .linear, duration: 5)
        try? await Task.sleep(for: .milliseconds(80))
        animator.stop()
        #expect(await run == false)
    }

    /// The display link must not keep the animator alive, and must clean itself
    /// up when the animator goes away underneath it.
    @Test func itDoesNotRetainItself() async {
        weak var weakAnimator: OffsetAnimator?
        let view = scrollView()

        do {
            let animator = OffsetAnimator()
            weakAnimator = animator
            _ = await animator.animate(view, to: CGPoint(x: -100, y: 0), easing: .linear, duration: 0.1)
        }

        // Let the runloop drain the display link's last tick.
        try? await Task.sleep(for: .milliseconds(50))
        #expect(weakAnimator == nil)
    }

    /// An animation built from a different curve is a different animation.
    @Test func animationsDifferByCurveNotJustDuration() {
        #expect(Animation.stackEasing(.linear, duration: 1) == .stackEasing(.linear, duration: 1))
        #expect(Animation.stackEasing(.linear, duration: 1) != .stackEasing(.bounceOut, duration: 1))
    }
}
#endif
