import CoreGraphics
import Testing
@testable import StackGeometry

@Suite("Rect subtraction")
struct RectSubtractionTests {
    private let unit = CGRect(x: 0, y: 0, width: 100, height: 100)

    @Test func equalRectsCollapse() {
        #expect(unit.subtracting(unit, edge: .minXEdge) == .zero)
    }

    @Test func nullIntersectionLeavesTheRectAlone() {
        #expect(unit.subtracting(CGRect(x: 500, y: 0, width: 10, height: 10), edge: .minXEdge) == unit)
    }

    @Test func chopsFromTheGivenEdge() {
        let left = CGRect(x: 0, y: 0, width: 40, height: 100)
        #expect(unit.subtracting(left, edge: .minXEdge) == CGRect(x: 40, y: 0, width: 60, height: 100))
        #expect(unit.subtracting(left, edge: .maxXEdge) == CGRect(x: 0, y: 0, width: 60, height: 100))

        let top = CGRect(x: 0, y: 0, width: 100, height: 30)
        #expect(unit.subtracting(top, edge: .minYEdge) == CGRect(x: 0, y: 30, width: 100, height: 70))
        #expect(unit.subtracting(top, edge: .maxYEdge) == CGRect(x: 0, y: 0, width: 100, height: 70))
    }

    @Test func edgeFromOffsetPrefersTheHorizontalAxis() {
        #expect(CGRect.edge(fromOffset: .zero) == nil)
        #expect(CGRect.edge(fromOffset: CGPoint(x: 1, y: -1)) == .minXEdge)
        #expect(CGRect.edge(fromOffset: CGPoint(x: -1, y: 1)) == .maxXEdge)
        #expect(CGRect.edge(fromOffset: CGPoint(x: 0, y: 1)) == .minYEdge)
        #expect(CGRect.edge(fromOffset: CGPoint(x: 0, y: -1)) == .maxYEdge)
    }
}

@Suite("Occlusion solver")
struct OcclusionSolverTests {

    @Test(arguments: StackPhysicalEdge.allCases)
    func nothingIsVisibleAtTheOrigin(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(edge, sizes: [Fixture.child(200, on: edge)])
        let resolution = StackOcclusionSolver.resolve(spec: spec, contentOffset: .zero)

        #expect(resolution.visibleItems.isEmpty)
        #expect(resolution.items[StackItemKey(edge: edge, index: 0)]?.visibleFraction == 0)
        #expect(resolution.root.isVisible)
        #expect(resolution.root.visibleFraction == 1)
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func oneChildIsFullyVisibleAtItsMaximumInset(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(edge, sizes: [Fixture.child(200, on: edge)])
        let resolution = StackOcclusionSolver.resolve(
            spec: spec, contentOffset: spec.maximumInset(at: edge)
        )
        let key = StackItemKey(edge: edge, index: 0)

        #expect(resolution.visibleItems == [key])
        #expect(resolution.items[key]?.visibleFraction == 1)
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func fractionTracksHowFarTheStackHasTravelled(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(edge, sizes: [Fixture.child(200, on: edge)])
        let key = StackItemKey(edge: edge, index: 0)

        for (travelled, expected) in [(50.0, 0.25), (100.0, 0.5), (150.0, 0.75)] {
            let offset = edge.axis.point(CGFloat(travelled) * edge.unfoldingSign)
            let resolution = StackOcclusionSolver.resolve(spec: spec, contentOffset: offset)
            #expect(resolution.items[key]?.visibleFraction == expected)
        }
    }

    /// A three-deep stack uncovers one child at a time, and the one being
    /// uncovered is the only partially visible one.
    @Test(arguments: StackPhysicalEdge.allCases)
    func deeperChildrenAreOccludedByTheirSiblings(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(
            edge,
            sizes: (0..<3).map { _ in Fixture.child(100, on: edge) }
        )
        let offset = edge.axis.point(150 * edge.unfoldingSign)
        let resolution = StackOcclusionSolver.resolve(spec: spec, contentOffset: offset)

        #expect(resolution.items[StackItemKey(edge: edge, index: 0)]?.visibleFraction == 1)
        #expect(resolution.items[StackItemKey(edge: edge, index: 1)]?.visibleFraction == 0.5)
        #expect(resolution.items[StackItemKey(edge: edge, index: 2)]?.visibleFraction == 0)
        #expect(resolution.visibleItems == [
            StackItemKey(edge: edge, index: 0),
            StackItemKey(edge: edge, index: 1)
        ])
    }

    /// The anchor for the live inset regime is the deepest visible child, which
    /// is why the ordering by `(edge, index)` matters.
    @Test func anchorIsTheDeepestVisibleChild() {
        let spec = Fixture.spec(.left, sizes: (0..<3).map { _ in Fixture.child(100, on: .left) })
        let resolution = StackOcclusionSolver.resolve(spec: spec, contentOffset: CGPoint(x: -250, y: 0))
        #expect(resolution.anchor == StackItemKey(edge: .left, index: 2))
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func stackingAboveRootLetsChildrenCoverIt(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(
            edge,
            sizes: [Fixture.child(200, on: edge)],
            layout: PlainStackLayout(stacksAboveRoot: true)
        )
        let resolution = StackOcclusionSolver.resolve(
            spec: spec, contentOffset: edge.axis.point(100 * edge.unfoldingSign)
        )
        // The root moves with the offset, so the child eats into it directly.
        #expect(resolution.root.visibleFraction < 1)
        #expect(resolution.items[StackItemKey(edge: edge, index: 0)]?.visibleFraction == 0.5)
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func fractionIsMonotoneAndBounded(edge: StackPhysicalEdge) {
        var rng = Rng(seed: 991)
        // The whole stack has to fit the container, or the children furthest
        // out legitimately scroll back off the far side and the fraction falls.
        let budget = Int(edge.axis.extent(of: Fixture.container)) / 3
        let sizes = (0..<3).map { _ in Fixture.child(CGFloat(rng.int(in: 40...budget)), on: edge) }
        let spec = Fixture.spec(edge, sizes: sizes)
        let span = abs(edge.axis.component(of: spec.maximumInset(at: edge)))

        var previous = [Double](repeating: 0, count: sizes.count)
        for tick in 0...120 {
            let travelled = span * CGFloat(tick) / 120
            let resolution = StackOcclusionSolver.resolve(
                spec: spec, contentOffset: edge.axis.point(travelled * edge.unfoldingSign)
            )
            for index in sizes.indices {
                let fraction = resolution.items[StackItemKey(edge: edge, index: index)]!.visibleFraction
                #expect(fraction >= 0 && fraction <= 1)
                #expect(fraction >= previous[index] - 1e-9, "child \(index) went backwards at tick \(tick)")
                previous[index] = fraction
            }
        }
        #expect(previous.allSatisfy { $0 == 1 })
    }

    /// Overlapping layouts must measure against the whole child, not the part
    /// left after its siblings are chopped off.
    @Test(arguments: StackPhysicalEdge.allCases, [false, true])
    func overlappingLayoutsReportTheirOwnFraction(edge: StackPhysicalEdge, parallax: Bool) {
        let spec = Fixture.spec(
            edge,
            sizes: (0..<2).map { _ in Fixture.child(100, on: edge) },
            layout: parallax ? ParallaxStackLayout() : SlidingStackLayout()
        )
        let early = StackOcclusionSolver.resolve(spec: spec, contentOffset: edge.axis.point(50 * edge.unfoldingSign))
        #expect(early.items[StackItemKey(edge: edge, index: 1)]?.visibleFraction == 0)

        let resolution = StackOcclusionSolver.resolve(spec: spec, contentOffset: edge.axis.point(150 * edge.unfoldingSign))
        #expect(resolution.items[StackItemKey(edge: edge, index: 0)]?.visibleFraction == 1)
        #expect(resolution.items[StackItemKey(edge: edge, index: 1)]?.visibleFraction == 0.5)
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func reversedStackUncoversTheNearestChildFirst(edge: StackPhysicalEdge) {
        let spec = Fixture.spec(
            edge,
            sizes: (0..<2).map { _ in Fixture.child(100, on: edge) },
            layout: ReversedStackLayout()
        )
        let resolution = StackOcclusionSolver.resolve(
            spec: spec, contentOffset: edge.axis.point(100 * edge.unfoldingSign)
        )
        #expect(resolution.items[StackItemKey(edge: edge, index: 0)]?.visibleFraction == 1)
        #expect(resolution.items[StackItemKey(edge: edge, index: 1)]?.visibleFraction == 0)
    }
}
