#if os(iOS)
import Testing
import UIKit
@testable import SCEdgeStack

@MainActor
@Suite("Content inset regimes")
struct InsetRegimeTests {

    @Test func aFreshStackGetsTheDefaultRange() {
        let harness = Bridge.harness(extents: [200], steps: [[.init(0.5)]])
        // Default constraints stop at the first child's first step.
        #expect(harness.insets.left == 100)
    }

    @Test func continuousNavigationOpensTheWholeRange() {
        let harness = Bridge.harness(extents: [200, 300], steps: [[.init(0.5)], []]) {
            $0.continuousNavigationEnabled = true
        }
        #expect(harness.insets.left == 500)
    }

    @Test func settlingInstallsTheLiveRange() {
        let harness = Bridge.harness(extents: [200], steps: [[.init(0.25), .init(0.5)]])

        harness.scrollView.contentOffset = CGPoint(x: -50, y: 0)
        harness.coordinator.scrollViewDidScroll(harness.scrollView)
        harness.coordinator.scrollViewDidEndDragging(harness.scrollView, willDecelerate: false)

        // Ahead: the 0.5 step. Behind: all the way home.
        #expect(harness.insets.left == 100)
        #expect(harness.insets.right == 0)
    }

    @Test func settlingOnAStepOpensTheNextSiblingsFirstStep() {
        let harness = Bridge.harness(extents: [200, 300], steps: [[], [.init(0.5)]])

        harness.scrollView.contentOffset = CGPoint(x: -200, y: 0)
        harness.coordinator.scrollViewDidScroll(harness.scrollView)
        harness.coordinator.scrollViewDidEndDecelerating(harness.scrollView)

        #expect(harness.insets.left == 350)
    }

    @Test func aScrollTickNeverWritesInsets() {
        let harness = Bridge.harness(extents: [200, 300], steps: [[.init(0.5)], []])
        let before = harness.insets

        for tick in 1...60 {
            harness.scrollView.contentOffset = CGPoint(x: -CGFloat(tick), y: 0)
            harness.coordinator.scrollViewDidScroll(harness.scrollView)
        }
        #expect(harness.insets == before)
    }

    /// Applying an inset must not move the stack.
    @Test func applyingInsetsPreservesTheOffset() {
        let harness = Bridge.harness(extents: [200, 300], steps: [[], [.init(0.5)]])

        harness.scrollView.contentOffset = CGPoint(x: -200, y: 0)
        harness.coordinator.scrollViewDidScroll(harness.scrollView)
        harness.coordinator.scrollViewDidEndDecelerating(harness.scrollView)

        #expect(harness.scrollView.contentOffset == CGPoint(x: -200, y: 0))
    }
}

@MainActor
@Suite("Deceleration target")
struct TargetOffsetTests {

    private func willEndDragging(
        _ harness: Bridge.Harness, velocity: CGPoint, target: CGPoint
    ) -> CGPoint {
        var target = target
        withUnsafeMutablePointer(to: &target) { pointer in
            harness.coordinator.scrollViewWillEndDragging(
                harness.scrollView, withVelocity: velocity, targetContentOffset: pointer
            )
        }
        return target
    }

    @Test func aFlickSnapsToTheNextStep() {
        let harness = Bridge.harness(extents: [200], steps: [[.init(0.5)]])
        let snapped = willEndDragging(
            harness, velocity: CGPoint(x: -1, y: 0), target: CGPoint(x: -30, y: 0)
        )
        #expect(snapped == CGPoint(x: -100, y: 0))
    }

    @Test func aSlowReleaseSnapsToTheNearestStep() {
        let harness = Bridge.harness(extents: [200], steps: [[.init(0.5)]])
        #expect(willEndDragging(harness, velocity: .zero, target: CGPoint(x: -20, y: 0)).x == 0)
        #expect(willEndDragging(harness, velocity: .zero, target: CGPoint(x: -90, y: 0)).x == -100)
    }

    /// Bouncing past the inset collapses the reported velocity, so pagination
    /// has to give way to a straight clamp.
    @Test func bouncingClampsToTheInsetInsteadOfPaginating() {
        let harness = Bridge.harness(extents: [200], steps: [[.init(0.5)]])
        harness.scrollView.contentOffset = CGPoint(x: -160, y: 0)

        let clamped = willEndDragging(
            harness, velocity: CGPoint(x: -0.01, y: 0), target: CGPoint(x: -150, y: 0)
        )
        #expect(clamped == CGPoint(x: -100, y: 0))
    }
}

@MainActor
@Suite("Rotation")
struct RotationTests {

    /// On a size change: capture the
    /// anchored fraction, widen the range, re-measure, restore.
    @Test func theAnchoredFractionSurvivesAResize() {
        let harness = Bridge.harness(extents: [200])

        harness.scrollView.contentOffset = CGPoint(x: -100, y: 0)
        harness.coordinator.scrollViewDidScroll(harness.scrollView)
        let fraction = harness.engine.resolution.items[harness.key(0)]?.visibleFraction
        #expect(fraction == 0.5)

        harness.coordinator.boundsSizeChanged(CGSize(width: 812, height: 375))
        harness.engine.commitMeasurements(
            containerSize: CGSize(width: 812, height: 375),
            descriptors: [
                StackItemDescriptor(
                    key: harness.key(0), token: StackItemToken(), id: .position(.leading, 0),
                    size: CGSize(width: 300, height: 375), steps: []
                )
            ]
        )

        // Half of the new 300pt child.
        #expect(abs(harness.scrollView.contentOffset.x + 150) <= 1)
        #expect(harness.engine.resolution.items[harness.key(0)]?.visibleFraction == 0.5)
    }

    @Test func theSentinelInsetIsFiniteSoUIKitCannotClamp() {
        let harness = Bridge.harness(extents: [200])
        harness.scrollView.contentOffset = CGPoint(x: -100, y: 0)
        harness.coordinator.scrollViewDidScroll(harness.scrollView)
        harness.coordinator.boundsSizeChanged(CGSize(width: 812, height: 375))

        #expect(harness.insets.left.isFinite)
        #expect(harness.insets.left > 1_000_000)
    }
}

@MainActor
@Suite("Update volume")
struct UpdateVolumeTests {

    /// The whole 120 Hz story in one assertion: sweeping the offset must not
    /// write to a child whose placement did not change.
    @Test func aFullSweepDoesNotTouchAnUnchangedChild() {
        let harness = Bridge.harness(edge: .leading, extents: [100, 100])
        let far = harness.engine.state(for: harness.key(1))

        // Drag across the first child only; the second never moves.
        harness.engine.apply(offset: CGPoint(x: -1, y: 0))
        let counter = PlacementWriteCounter(watching: far)
        for tick in 1...120 {
            harness.engine.apply(offset: CGPoint(x: -CGFloat(tick) * 100 / 120, y: 0))
        }
        #expect(counter.writes == 0)
    }

    /// The pull API's backing store: the per-item observable the environment
    /// carries has to actually receive the solve.
    @Test func perItemStateReceivesTheSolve() {
        let harness = Bridge.harness(extents: [200])
        let state = harness.engine.state(for: harness.key(0))
        #expect(state.visibleFraction == 0)

        harness.engine.apply(offset: CGPoint(x: -200, y: 0))
        #expect(state.visibleFraction == 1)
        #expect(state.isVisible)

        harness.engine.apply(offset: .zero)
        #expect(state.visibleFraction == 0)
    }

    @Test func repeatingAnOffsetIsANoOp() {
        let harness = Bridge.harness(extents: [200])
        harness.engine.apply(offset: CGPoint(x: -50, y: 0))
        let near = harness.engine.state(for: harness.key(0))

        let counter = PlacementWriteCounter(watching: near)
        for _ in 0..<120 { harness.engine.apply(offset: CGPoint(x: -50, y: 0)) }
        #expect(counter.writes == 0)
    }
}

@Suite("Configuration changes")
@MainActor
struct ConfigurationChangeTests {

    /// Swapping an edge's layout takes effect at once, without waiting for the
    /// children to be measured again.
    @Test func aNewLayoutAppliesWithoutARemeasure() {
        let harness = Bridge.harness(extents: [200])
        harness.scrollView.contentOffset = CGPoint(x: -100, y: 0)
        harness.coordinator.scrollViewDidScroll(harness.scrollView)
        #expect(harness.engine.resolution.items[harness.key(0)]?.frame.minX == -200, "plain: the child sits still")

        harness.engine.configuration.layouts[.leading] = SlidingStackLayout()
        #expect(harness.engine.resolution.items[harness.key(0)]?.frame.minX == -100, "sliding: the child tracks the offset")
    }

    @Test func anUnchangedLayoutDoesNotResolveAgain() {
        let harness = Bridge.harness(extents: [200])
        harness.scrollView.contentOffset = CGPoint(x: -100, y: 0)
        harness.coordinator.scrollViewDidScroll(harness.scrollView)
        let counter = PlacementWriteCounter(watching: harness.engine.state(for: harness.key(0)))

        var configuration = harness.engine.configuration
        configuration.pagingEnabled.toggle()
        harness.engine.configuration = configuration

        #expect(counter.writes == 0)
    }
}
#endif
