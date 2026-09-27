import CoreGraphics
import Testing
@testable import StackGeometry

@Suite("Step solver")
struct StepSolverTests {

    /// The affine normal form, derived independently of the solver's
    /// implementation, evaluated for one child filling half the container.
    @Test(arguments: StackPhysicalEdge.allCases, [false, true])
    func offsetIsAffineInFraction(edge: StackPhysicalEdge, reversed: Bool) {
        let extent: CGFloat = 200
        let spec = Fixture.spec(
            edge,
            sizes: [Fixture.child(extent, on: edge)],
            layout: reversed ? ReversedStackLayout() : PlainStackLayout()
        )
        let frame = spec.finalFrames(at: edge)[0]
        let maximumInset = spec.maximumInset(at: edge)

        func solved(_ p: Double) -> CGFloat {
            StackStepSolver.offset(
                fraction: p, edge: edge, reversed: reversed,
                finalFrame: frame, maximumInset: maximumInset, containerSize: spec.containerSize
            )
        }

        let at0 = solved(0)
        let at1 = solved(1)
        // Affine: the midpoint is the mean, and the slope has the sign of travel.
        #expect(abs(solved(0.5) - (at0 + at1) / 2) < 1e-9)
        #expect((at1 - at0) * edge.unfoldingSign > 0)
        #expect(abs(abs(at1 - at0) - extent) < 1e-9)
    }

    /// Folded is the origin, full is `maximumInset`. This is what makes the
    /// scroll range equal to the content inset.
    @Test(arguments: StackPhysicalEdge.allCases)
    func plainSingleChildSpansOriginToMaximumInset(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(edge, sizes: [Fixture.child(120, on: edge)])
        let frame = spec.finalFrames(at: edge)[0]
        let maximumInset = spec.maximumInset(at: edge)

        let folded = StackStepSolver.offset(
            fraction: 0, edge: edge, reversed: false,
            finalFrame: frame, maximumInset: maximumInset, containerSize: spec.containerSize
        )
        let full = StackStepSolver.offset(
            fraction: 1, edge: edge, reversed: false,
            finalFrame: frame, maximumInset: maximumInset, containerSize: spec.containerSize
        )

        #expect(abs(folded) < 1e-9)
        #expect(abs(full - edge.axis.component(of: maximumInset)) < 1e-9)
    }

    /// The `(1 - p)` in the top/left reversed rows is not a typo. Reversed
    /// children are laid out from the container bounds inwards, so their final
    /// frame already sits at the far end and the fraction has to count back.
    @Test(arguments: [StackPhysicalEdge.top, .left])
    func reversedLeadingEdgesCountBackwards(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(
            edge,
            sizes: [Fixture.child(100, on: edge), Fixture.child(140, on: edge)],
            layout: ReversedStackLayout()
        )
        let frames = spec.finalFrames(at: edge)
        let maximumInset = spec.maximumInset(at: edge)

        // Index 0 is adjacent to the root, so unfolding it fully must land at
        // exactly its own extent -- not the whole stack's.
        let full = StackStepSolver.offset(
            fraction: 1, edge: edge, reversed: true,
            finalFrame: frames[0], maximumInset: maximumInset, containerSize: spec.containerSize
        )
        #expect(abs(abs(full) - 100) < 1e-9)

        let both = StackStepSolver.offset(
            fraction: 1, edge: edge, reversed: true,
            finalFrame: frames[1], maximumInset: maximumInset, containerSize: spec.containerSize
        )
        #expect(abs(abs(both) - 240) < 1e-9)
    }

    /// The two composed sign flips plus the `maximumInset` term: the rows most
    /// likely to be wrong and least likely to be noticed.
    @Test(arguments: [StackPhysicalEdge.bottom, .right])
    func reversedTrailingEdgesCountForwards(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(
            edge,
            sizes: [Fixture.child(100, on: edge), Fixture.child(140, on: edge)],
            layout: ReversedStackLayout()
        )
        let frames = spec.finalFrames(at: edge)
        let maximumInset = spec.maximumInset(at: edge)

        let full = StackStepSolver.offset(
            fraction: 1, edge: edge, reversed: true,
            finalFrame: frames[0], maximumInset: maximumInset, containerSize: spec.containerSize
        )
        #expect(abs(abs(full) - 100) < 1e-9)

        let both = StackStepSolver.offset(
            fraction: 1, edge: edge, reversed: true,
            finalFrame: frames[1], maximumInset: maximumInset, containerSize: spec.containerSize
        )
        #expect(abs(abs(both) - 240) < 1e-9)
    }

    @Test(arguments: StackPhysicalEdge.allCases, [false, true])
    func picksTheNearestStepStrictlyAhead(edge: StackPhysicalEdge, reversed: Bool) {
        let steps: [StackNavigationStep] = [.init(0.25), .init(0.5), .init(0.75)]
        let spec = Fixture.spec(
            edge,
            sizes: [Fixture.child(200, on: edge)],
            steps: [steps],
            layout: reversed ? ReversedStackLayout() : PlainStackLayout()
        )

        func offset(_ p: Double) -> CGPoint {
            edge.axis.point(
                StackStepSolver.offset(
                    fraction: p, edge: edge, reversed: reversed,
                    finalFrame: spec.finalFrames(at: edge)[0],
                    maximumInset: spec.maximumInset(at: edge),
                    containerSize: spec.containerSize
                ).rounded()
            )
        }

        let unfolded = Fixture.nextStep(spec, edge: edge, index: 0, travel: .unfolding, contentOffset: offset(0.3))
        #expect(unfolded.step.fraction == 0.5)

        let folded = Fixture.nextStep(spec, edge: edge, index: 0, travel: .folding, contentOffset: offset(0.8))
        #expect(folded.step.fraction == 0.75)
    }

    @Test(arguments: StackPhysicalEdge.allCases, [false, true])
    func fallsBackToTheFarEndWhenNothingIsAhead(edge: StackPhysicalEdge, reversed: Bool) {
        let spec = Fixture.spec(
            edge,
            sizes: [Fixture.child(200, on: edge)],
            steps: [[.init(0.5)]],
            layout: reversed ? ReversedStackLayout() : PlainStackLayout()
        )
        let maximumInset = spec.maximumInset(at: edge)

        let unfolded = Fixture.nextStep(
            spec, edge: edge, index: 0, travel: .unfolding, contentOffset: maximumInset
        )
        #expect(unfolded.step.fraction == 1)
        #expect(abs(edge.axis.component(of: unfolded.offset) - edge.axis.component(of: maximumInset)) <= 0.5)

        let folded = Fixture.nextStep(spec, edge: edge, index: 0, travel: .folding, contentOffset: .zero)
        #expect(folded.step.fraction == 0)
        #expect(abs(edge.axis.component(of: folded.offset)) <= 0.5)
    }

    /// The cross-axis component is zeroed, because the
    /// result is handed straight to `targetContentOffset` under directional lock.
    @Test(arguments: StackPhysicalEdge.allCases)
    func crossAxisIsZeroed(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(edge, sizes: [Fixture.child(200, on: edge)])
        let result = Fixture.nextStep(
            spec, edge: edge, index: 0, travel: .unfolding,
            contentOffset: CGPoint(x: 17, y: 23)
        )
        let cross: StackAxis = edge.axis == .horizontal ? .vertical : .horizontal
        #expect(cross.component(of: result.offset) == 0)
    }

    @Test func blockingStepPinsTheSearchWhenSittingOnIt() {
        let edge = StackPhysicalEdge.top
        let spec = Fixture.spec(
            edge,
            sizes: [Fixture.child(200, on: edge)],
            steps: [[.init(0.5, block: .unfolding)]]
        )
        let half = edge.axis.point(
            StackStepSolver.offset(
                fraction: 0.5, edge: edge, reversed: false,
                finalFrame: spec.finalFrames(at: edge)[0],
                maximumInset: spec.maximumInset(at: edge),
                containerSize: spec.containerSize
            ).rounded()
        )

        // Sitting exactly on the blocking step, the search must not advance.
        let blocked = Fixture.nextStep(spec, edge: edge, index: 0, travel: .unfolding, contentOffset: half)
        #expect(blocked.step.fraction == 0.5)

        // The same step without a block lets the search through to the bound.
        let open = Fixture.spec(edge, sizes: [Fixture.child(200, on: edge)], steps: [[.init(0.5)]])
        let through = Fixture.nextStep(open, edge: edge, index: 0, travel: .unfolding, contentOffset: half)
        #expect(through.step.fraction == 1)
    }

    @Test func blockingStepIsTransparentWhilePaginating() {
        let edge = StackPhysicalEdge.top
        let spec = Fixture.spec(
            edge,
            sizes: [Fixture.child(200, on: edge)],
            steps: [[.init(0.5, block: .unfolding)]]
        )
        let half = edge.axis.point(
            StackStepSolver.offset(
                fraction: 0.5, edge: edge, reversed: false,
                finalFrame: spec.finalFrames(at: edge)[0],
                maximumInset: spec.maximumInset(at: edge),
                containerSize: spec.containerSize
            ).rounded()
        )
        let result = Fixture.nextStep(
            spec, edge: edge, index: 0, travel: .unfolding, contentOffset: half, paginating: true
        )
        #expect(result.step.fraction == 1)
    }

    @Test func stepFractionsAreClampedAndOrdered() {
        #expect(StackNavigationStep(-3).fraction == 0)
        #expect(StackNavigationStep(42).fraction == 1)
        #expect(StackNavigationStep(0.3) < StackNavigationStep(0.7))

        // Declared steps beat the implicit bounds at the same fraction.
        let declared = StackNavigationStep(1, block: .folding)
        let candidates = [declared].candidates(towards: .unfolding)
        #expect(candidates.count == 1)
        #expect(candidates[0].block == .folding)
    }
}
