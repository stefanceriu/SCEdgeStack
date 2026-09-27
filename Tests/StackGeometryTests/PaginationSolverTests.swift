import CoreGraphics
import Testing
@testable import StackGeometry

@Suite("Pagination solver")
struct PaginationSolverTests {

    private func spec(_ edge: StackPhysicalEdge) -> StackSpec {
        Fixture.spec(edge, sizes: [Fixture.child(200, on: edge)], steps: [[.init(0.5)]])
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func travelFollowsTheVelocitySign(edge: StackPhysicalEdge) {
        let outwards = edge.axis.point(edge.unfoldingSign)
        let inwards = edge.axis.point(-edge.unfoldingSign)
        #expect(StackPaginationSolver.travel(for: outwards, edge: edge) == .unfolding)
        #expect(StackPaginationSolver.travel(for: inwards, edge: edge) == .folding)
        #expect(StackPaginationSolver.travel(for: .zero, edge: edge) == nil)
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func aFlickSnapsToTheNextStepInThatDirection(edge: StackPhysicalEdge) {
        let spec = spec(edge)
        let target = edge.axis.point(30 * edge.unfoldingSign)
        let result = StackPaginationSolver.adjustedTarget(
            spec: spec, target: target,
            velocity: edge.axis.point(edge.unfoldingSign),
            pagingEnabled: true
        )
        #expect(result?.step.fraction == 0.5)
        #expect(result.map { abs(edge.axis.component(of: $0.offset)) } == 100)
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func noVelocitySnapsToTheNearerNeighbour(edge: StackPhysicalEdge) {
        let spec = spec(edge)

        let nearFolded = StackPaginationSolver.adjustedTarget(
            spec: spec, target: edge.axis.point(20 * edge.unfoldingSign), velocity: .zero,
            pagingEnabled: true
        )
        #expect(nearFolded?.step.fraction == 0)

        let nearHalf = StackPaginationSolver.adjustedTarget(
            spec: spec, target: edge.axis.point(90 * edge.unfoldingSign), velocity: .zero,
            pagingEnabled: true
        )
        #expect(nearHalf?.step.fraction == 0.5)
    }

    /// With paging off a drag comes to rest wherever it decelerates to.
    @Test func withoutPagingTheTargetIsLeftAlone() {
        let result = StackPaginationSolver.adjustedTarget(
            spec: spec(.left), target: CGPoint(x: -30, y: 0), velocity: CGPoint(x: -1, y: 0),
            pagingEnabled: false
        )
        #expect(result == nil)
    }

    @Test func aTargetOutsideEveryChildIsLeftAlone() {
        let result = StackPaginationSolver.adjustedTarget(
            spec: spec(.left), target: CGPoint(x: 400, y: 0), velocity: CGPoint(x: 1, y: 0),
            pagingEnabled: true
        )
        #expect(result == nil)
    }

    @Test func bounceClampPinsToTheInsetInsteadOfPaginating() {
        let insets = StackInsets(top: 0, left: 200, bottom: 0, right: 0)
        let clamped = StackPaginationSolver.bounceClamp(
            contentOffset: CGPoint(x: -260, y: 0), insets: insets, target: CGPoint(x: -240, y: 0)
        )
        #expect(clamped == CGPoint(x: -200, y: 0))

        let inRange = StackPaginationSolver.bounceClamp(
            contentOffset: CGPoint(x: -100, y: 0), insets: insets, target: CGPoint(x: -120, y: 0)
        )
        #expect(inRange == nil)
    }
}
