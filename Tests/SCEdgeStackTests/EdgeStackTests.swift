#if os(iOS)
import SwiftUI
import Testing
@testable import SCEdgeStack

@Suite("Step callback", .timeLimit(.minutes(1)))
@MainActor
struct StepCallbackTests {

    @MainActor
    private final class Steps {
        var reported: [(StackItemID, StackNavigationStep)] = []
    }

    /// A drag released near a step decelerates onto it and reports it once settled.
    @Test func settlingAfterADragReportsTheStep() {
        let steps = Steps()
        let harness = Bridge.harness(extents: [200], steps: [[.init(0.5)]]) { configuration in
            configuration.onStep = { steps.reported.append(($0, $1)) }
        }

        var target = CGPoint(x: -90, y: 0)
        withUnsafeMutablePointer(to: &target) { pointer in
            harness.coordinator.scrollViewWillEndDragging(
                harness.scrollView, withVelocity: .zero, targetContentOffset: pointer
            )
        }
        harness.scrollView.contentOffset = target
        harness.coordinator.scrollViewDidEndDecelerating(harness.scrollView)

        #expect(steps.reported.count == 1)
        #expect(steps.reported.first?.0 == .position(.leading, 0))
        #expect(steps.reported.first?.1 == .init(0.5))
    }

    /// A drag that ends against the live range is clamped rather than
    /// paginated, and still reports the step it actually settled on.
    @Test func aClampedDragReportsTheStepItSettledOn() {
        let steps = Steps()
        let harness = Bridge.harness(extents: [200], steps: [[.init(0.5)]]) { configuration in
            configuration.onStep = { steps.reported.append(($0, $1)) }
        }
        harness.scrollView.contentOffset = CGPoint(x: -160, y: 0)
        harness.coordinator.scrollViewDidScroll(harness.scrollView)

        var target = CGPoint(x: -150, y: 0)
        withUnsafeMutablePointer(to: &target) { pointer in
            harness.coordinator.scrollViewWillEndDragging(
                harness.scrollView, withVelocity: CGPoint(x: -0.01, y: 0), targetContentOffset: pointer
            )
        }
        #expect(target == CGPoint(x: -100, y: 0))
        harness.scrollView.contentOffset = target
        harness.coordinator.scrollViewDidScroll(harness.scrollView)
        harness.coordinator.scrollViewDidEndDecelerating(harness.scrollView)

        #expect(steps.reported.map(\.1) == [.init(0.5)])
    }

    @Test func settlingBackAtTheRootReportsTheRoot() {
        let steps = Steps()
        let harness = Bridge.harness(extents: [200], steps: [[.init(0.5)]]) { configuration in
            configuration.onStep = { steps.reported.append(($0, $1)) }
        }

        var target = CGPoint(x: -20, y: 0)
        withUnsafeMutablePointer(to: &target) { pointer in
            harness.coordinator.scrollViewWillEndDragging(
                harness.scrollView, withVelocity: .zero, targetContentOffset: pointer
            )
        }
        harness.scrollView.contentOffset = target
        harness.coordinator.scrollViewDidEndDecelerating(harness.scrollView)

        #expect(steps.reported.first?.0 == .root)
    }
}
#endif
