#if os(iOS)
import UIKit
import Testing
@testable import SCEdgeStack

@MainActor
private final class Events {
    var visibility: [(StackItemID, Bool)] = []
    var steps: [(StackItemID, StackNavigationStep)] = []
}

@MainActor
private func descriptor(_ id: String, _ index: Int, width: CGFloat = 200) -> StackItemDescriptor {
    StackItemDescriptor(
        key: StackItemKey(edge: .left, index: index),
        token: StackItemToken(),
        id: StackItemID(id),
        size: CGSize(width: width, height: Bridge.container.height),
        steps: []
    )
}

@Suite("Per-child state")
@MainActor
struct ChildStateTests {

    @Test func aRemeasureDoesNotReannounceVisibleChildren() {
        let events = Events()
        let engine = StackEngine()
        engine.configuration.onVisibilityChange = { events.visibility.append(($0, $1)) }
        engine.commitMeasurements(containerSize: Bridge.container, descriptors: [descriptor("a", 0), descriptor("b", 1)])
        engine.apply(offset: CGPoint(x: -200, y: 0))
        #expect(events.visibility.map(\.0) == [StackItemID("a")])

        engine.commitMeasurements(containerSize: Bridge.container, descriptors: [descriptor("a", 0, width: 250), descriptor("b", 1)])
        #expect(events.visibility.count == 1)
    }

    @Test func removingAVisibleChildAnnouncesItHidden() {
        let events = Events()
        let engine = StackEngine()
        engine.configuration.onVisibilityChange = { events.visibility.append(($0, $1)) }
        engine.commitMeasurements(containerSize: Bridge.container, descriptors: [descriptor("a", 0)])
        engine.apply(offset: CGPoint(x: -200, y: 0))

        engine.commitMeasurements(containerSize: Bridge.container, descriptors: [])
        #expect(events.visibility.last?.0 == StackItemID("a"))
        #expect(events.visibility.last?.1 == false)
    }

    /// A child's state belongs to the child, so it follows it through a
    /// reorder and reports the right identity.
    @Test func stateFollowsItsChildThroughAReorder() {
        let engine = StackEngine()
        engine.commitMeasurements(containerSize: Bridge.container, descriptors: [descriptor("a", 0), descriptor("b", 1)])
        let a = engine.state(for: StackItemKey(edge: .left, index: 0))
        #expect(a.id == StackItemID("a"))

        engine.commitMeasurements(containerSize: Bridge.container, descriptors: [descriptor("b", 0), descriptor("a", 1)])
        #expect(engine.state(for: StackItemKey(edge: .left, index: 1)) === a)
        #expect(engine.state(for: StackItemKey(edge: .left, index: 0)).id == StackItemID("b"))
    }

    /// With paging off a drag can rest between steps, where there is no step
    /// to report.
    @Test func restingBetweenStepsReportsNothing() {
        let events = Events()
        let harness = Bridge.harness(extents: [200], steps: [[.init(0.5)]]) { configuration in
            configuration.pagingEnabled = false
            configuration.onStep = { events.steps.append(($0, $1)) }
        }
        harness.scrollView.contentOffset = CGPoint(x: -60, y: 0)
        harness.coordinator.scrollViewDidScroll(harness.scrollView)
        harness.coordinator.scrollViewDidEndDecelerating(harness.scrollView)
        #expect(events.steps.isEmpty)

        harness.scrollView.contentOffset = CGPoint(x: -100, y: 0)
        harness.coordinator.scrollViewDidScroll(harness.scrollView)
        harness.coordinator.scrollViewDidEndDecelerating(harness.scrollView)
        #expect(events.steps.map(\.1) == [.init(0.5)])
    }
}
#endif
