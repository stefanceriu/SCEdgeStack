#if os(iOS)
import UIKit
import Testing
@testable import SCEdgeStack

@Suite("Drag activation")
@MainActor
struct DragActivationTests {
    private func scrollView(offset: CGPoint = .zero) -> PassthroughScrollView {
        let view = PassthroughScrollView(frame: CGRect(origin: .zero, size: Bridge.container))
        view.dragActivation = .edges([.leading], width: 30)
        view.contentOffset = offset
        return view
    }

    @Test func atRestADragOpensOnlyFromTheEdge() {
        let view = scrollView()
        #expect(view.allowsDrag(from: CGPoint(x: 10, y: 400), velocity: CGPoint(x: 100, y: 0)))
        #expect(!view.allowsDrag(from: CGPoint(x: 200, y: 400), velocity: CGPoint(x: 100, y: 0)))
        #expect(!view.allowsDrag(from: CGPoint(x: 10, y: 400), velocity: CGPoint(x: -100, y: 0)))
    }

    /// Once something is open, a drag from anywhere can close it.
    @Test func unfoldedADragFromAnywhereMoves() {
        let view = scrollView(offset: CGPoint(x: -200, y: 0))
        #expect(view.allowsDrag(from: CGPoint(x: 100, y: 400), velocity: CGPoint(x: 100, y: 0)))
        #expect(view.allowsDrag(from: CGPoint(x: 100, y: 400), velocity: CGPoint(x: -100, y: 0)))
    }

    @Test func anywhereAlwaysAllows() {
        let view = scrollView()
        view.dragActivation = .anywhere
        #expect(view.allowsDrag(from: CGPoint(x: 200, y: 400), velocity: CGPoint(x: 100, y: 0)))
    }
}

@Suite("Scroll range")
@MainActor
struct ScrollRangeTests {
    /// Removing an unfolded child shrinks the range; the offset has to follow,
    /// or the stack rests beyond it until the next touch.
    @Test func removingAnUnfoldedChildPullsTheOffsetBackIntoRange() {
        let harness = Bridge.harness(extents: [200, 200])
        harness.scrollView.contentOffset = CGPoint(x: -400, y: 0)
        harness.coordinator.scrollViewDidScroll(harness.scrollView)

        harness.engine.commitMeasurements(
            containerSize: Bridge.container,
            descriptors: [
                StackItemDescriptor(
                    key: harness.key(0), token: StackItemToken(), id: .position(.leading, 0),
                    size: CGSize(width: 200, height: Bridge.container.height), steps: []
                )
            ]
        )

        #expect(harness.scrollView.contentOffset == CGPoint(x: -200, y: 0))
        #expect(harness.engine.resolution.contentOffset == CGPoint(x: -200, y: 0))
    }
}
#endif
