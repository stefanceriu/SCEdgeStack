import CoreGraphics
import Testing
@testable import StackGeometry

@Suite("Inset solver")
struct InsetSolverTests {

    @Test(arguments: StackPhysicalEdge.allCases, [0, 1, 3])
    func unconstrainedReachesEveryChild(edge: StackPhysicalEdge, count: Int) {
        let sizes = (0..<count).map { Fixture.child(CGFloat(60 + $0 * 40), on: edge) }
        let spec = Fixture.spec(edge, sizes: sizes)
        let insets = StackInsetSolver.resolve(spec: spec, regime: .unconstrained).insets

        let expected = sizes.reduce(CGFloat.zero) { $0 + edge.axis.extent(of: $1) }
        #expect(insets[edge] == expected)

        for other in StackPhysicalEdge.allCases where other != edge {
            #expect(insets[other] == 0)
        }
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func defaultConstraintsStopAtTheFirstStepOfTheFirstChild(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(
            edge,
            sizes: [Fixture.child(200, on: edge), Fixture.child(300, on: edge)],
            steps: [[.init(0.5)], []]
        )
        let insets = StackInsetSolver.resolve(spec: spec, regime: .defaultConstraints).insets
        #expect(insets[edge] == 100)
    }

    /// With unfolding unconstrained the default regime degrades to the
    /// unconstrained one.
    @Test(arguments: StackPhysicalEdge.allCases)
    func defaultConstraintsWithoutUnfoldingIsUnconstrained(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(edge, sizes: [Fixture.child(200, on: edge)], steps: [[.init(0.5)]])
        let insets = StackInsetSolver.resolve(
            spec: spec, regime: .defaultConstraints, constraints: .folding
        ).insets
        #expect(insets[edge] == 200)
    }

    @Test func liveRegimeFallsBackToDefaultsWithNoAnchor() {
        let spec = Fixture.spec(.left, sizes: [Fixture.child(200, on: .left)], steps: [[.init(0.5)]])
        let resolution = StackInsetSolver.resolve(
            spec: spec, regime: .live(contentOffset: CGPoint(x: -40, y: 0), anchor: nil)
        )
        #expect(resolution.insets.left == 100)
    }

    @Test func liveRegimeFallsBackToDefaultsAtTheOrigin() {
        let spec = Fixture.spec(.left, sizes: [Fixture.child(200, on: .left)], steps: [[.init(0.5)]])
        let resolution = StackInsetSolver.resolve(
            spec: spec,
            regime: .live(contentOffset: .zero, anchor: StackItemKey(edge: .left, index: 0))
        )
        #expect(resolution.insets == StackInsetSolver.resolve(spec: spec, regime: .defaultConstraints).insets)
    }

    /// The live regime brackets the current position: the next step ahead in the
    /// scroll range, and the whole stack behind it so folding is always possible.
    @Test(arguments: StackPhysicalEdge.allCases)
    func liveRegimeBracketsTheCurrentPosition(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(
            edge,
            sizes: [Fixture.child(200, on: edge)],
            steps: [[.init(0.25), .init(0.5), .init(0.75)]]
        )
        let offset = edge.axis.point(50 * edge.unfoldingSign)
        let insets = StackInsetSolver.resolve(
            spec: spec,
            regime: .live(contentOffset: offset, anchor: StackItemKey(edge: edge, index: 0))
        ).insets

        // Ahead: the 0.5 step at 100pt.
        #expect(insets[edge] == 100)

        // Behind: all the way back to the root.
        let opposite: StackPhysicalEdge = switch edge {
        case .top: .bottom
        case .bottom: .top
        case .left: .right
        case .right: .left
        }
        #expect(insets[opposite] == 0)
    }

    /// Sitting exactly on a child's last step, the next drag has to be able to
    /// reach the following child's first step.
    @Test(arguments: StackPhysicalEdge.allCases)
    func liveRegimeHopsToTheNextSibling(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(
            edge,
            sizes: [Fixture.child(200, on: edge), Fixture.child(300, on: edge)],
            steps: [[], [.init(0.5)]]
        )
        // Fully unfolded on child 0 -> 200pt travelled.
        let offset = edge.axis.point(200 * edge.unfoldingSign)
        let insets = StackInsetSolver.resolve(
            spec: spec,
            regime: .live(contentOffset: offset, anchor: StackItemKey(edge: edge, index: 0))
        ).insets

        // Child 1's 0.5 step is at 200 + 150.
        #expect(insets[edge] == 350)
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func liveRegimeDoesNotHopWhenItIsTheLastSibling(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(edge, sizes: [Fixture.child(200, on: edge)])
        let offset = edge.axis.point(200 * edge.unfoldingSign)
        let insets = StackInsetSolver.resolve(
            spec: spec,
            regime: .live(contentOffset: offset, anchor: StackItemKey(edge: edge, index: 0))
        ).insets
        #expect(insets[edge] == 200)
    }

    /// The offset is compared against a rounded inset; half a point of slack
    /// makes that comparison survivable.
    @Test func siblingHopToleratesHalfAPointOfRoundingError() {
        let edge = StackPhysicalEdge.top
        let spec = Fixture.spec(
            edge,
            sizes: [Fixture.child(200.4, on: edge), Fixture.child(300, on: edge)],
            steps: [[], [.init(0.5)]]
        )
        let insets = StackInsetSolver.resolve(
            spec: spec,
            regime: .live(contentOffset: CGPoint(x: 0, y: -200), anchor: StackItemKey(edge: edge, index: 0))
        ).insets
        #expect(insets.top == 350)
    }

    /// A plain step stops one drag and hands the rest to the next: once the
    /// stack has settled on it the range opens up to the following step.
    @Test(arguments: StackPhysicalEdge.allCases)
    func aPlainStepReleasesOnceSettledOnIt(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(edge, sizes: [Fixture.child(200, on: edge)], steps: [[.init(0.5)]])

        let firstDrag = StackInsetSolver.resolve(spec: spec, regime: .defaultConstraints).insets
        #expect(firstDrag[edge] == 100)

        let settled = StackInsetSolver.resolve(
            spec: spec,
            regime: .live(
                contentOffset: edge.axis.point(100 * edge.unfoldingSign),
                anchor: StackItemKey(edge: edge, index: 0)
            )
        ).insets
        #expect(settled[edge] == 200, "the second drag must reach the far end")
    }

    /// A block is a hard limit, not a speed bump: settling on it does not open
    /// the range, so no number of drags gets past it.
    @Test(arguments: StackPhysicalEdge.allCases)
    func ABlockingStepNeverReleases(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(
            edge, sizes: [Fixture.child(200, on: edge)], steps: [[.init(0.5, block: .unfolding)]]
        )

        for _ in 0..<3 {
            let insets = StackInsetSolver.resolve(
                spec: spec,
                regime: .live(
                    contentOffset: edge.axis.point(100 * edge.unfoldingSign),
                    anchor: StackItemKey(edge: edge, index: 0)
                )
            ).insets
            #expect(insets[edge] == 100)
        }
    }

    /// The hop to the next sibling's first step must not jump a block either.
    @Test(arguments: StackPhysicalEdge.allCases)
    func aBlockingStepHoldsWithASiblingBeyondIt(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(
            edge,
            sizes: [Fixture.child(200, on: edge), Fixture.child(300, on: edge)],
            steps: [[.init(0.5, block: .unfolding)], []]
        )

        let insets = StackInsetSolver.resolve(
            spec: spec,
            regime: .live(
                contentOffset: edge.axis.point(100 * edge.unfoldingSign),
                anchor: StackItemKey(edge: edge, index: 0)
            )
        ).insets
        #expect(insets[edge] == 100)
    }

    @Test func insetsAreRounded() {
        let raw = StackInsets(top: 10.4, left: 10.5, bottom: -10.4, right: -10.5)
        #expect(raw.rounded() == StackInsets(top: 10, left: 11, bottom: -10, right: -11))
    }

    @Test func mixedEdgesEachGetTheirOwnUnconstrainedInset() {
        let spec = StackSpec(
            containerSize: Fixture.container,
            edges: [
                .top: StackEdgeSpec(items: [StackItemSpec(size: Fixture.child(64, on: .top))]),
                .left: StackEdgeSpec(items: [StackItemSpec(size: Fixture.child(280, on: .left))]),
                .bottom: StackEdgeSpec(items: [StackItemSpec(size: Fixture.child(120, on: .bottom))]),
                .right: StackEdgeSpec(items: [StackItemSpec(size: Fixture.child(90, on: .right))])
            ]
        )
        let insets = StackInsetSolver.resolve(spec: spec, regime: .unconstrained).insets
        #expect(insets == StackInsets(top: 64, left: 280, bottom: 120, right: 90))
    }
}
