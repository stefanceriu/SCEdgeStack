import CoreGraphics
import Testing
@testable import StackGeometry

@Suite("Edges")
struct EdgeTests {

    @Test func leadingAndTrailingFollowTheLayoutDirection() {
        #expect(StackEdge.leading.resolved(.leftToRight) == .left)
        #expect(StackEdge.trailing.resolved(.leftToRight) == .right)
        #expect(StackEdge.leading.resolved(.rightToLeft) == .right)
        #expect(StackEdge.trailing.resolved(.rightToLeft) == .left)
    }

    @Test(arguments: [StackLayoutDirection.leftToRight, .rightToLeft])
    func topAndBottomIgnoreTheLayoutDirection(direction: StackLayoutDirection) {
        #expect(StackEdge.top.resolved(direction) == .top)
        #expect(StackEdge.bottom.resolved(direction) == .bottom)
    }

    @Test func everyDeclaredEdgeResolvesToADistinctPhysicalOne() {
        for direction in [StackLayoutDirection.leftToRight, .rightToLeft] {
            let resolved = Set(StackEdge.allCases.map { $0.resolved(direction) })
            #expect(resolved == Set(StackPhysicalEdge.allCases))
        }
    }

    @Test func axes() {
        #expect(StackPhysicalEdge.top.axis == .vertical)
        #expect(StackPhysicalEdge.bottom.axis == .vertical)
        #expect(StackPhysicalEdge.left.axis == .horizontal)
        #expect(StackPhysicalEdge.right.axis == .horizontal)
    }

    /// Top and left unfold towards negative offsets, bottom and right towards positive.
    @Test func unfoldingSigns() {
        #expect(StackPhysicalEdge.top.unfoldingSign == -1)
        #expect(StackPhysicalEdge.left.unfoldingSign == -1)
        #expect(StackPhysicalEdge.bottom.unfoldingSign == 1)
        #expect(StackPhysicalEdge.right.unfoldingSign == 1)
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func foldingIsTheOppositeSign(edge: StackPhysicalEdge) {
        #expect(edge.sign(for: .unfolding) == edge.unfoldingSign)
        #expect(edge.sign(for: .folding) == -edge.unfoldingSign)
        #expect(StackTravel.unfolding.opposite == .folding)
        #expect(StackTravel.folding.opposite == .unfolding)
    }

    @Test func axisProjections() {
        let size = CGSize(width: 3, height: 5)
        let point = CGPoint(x: 7, y: 11)
        #expect(StackAxis.horizontal.extent(of: size) == 3)
        #expect(StackAxis.vertical.extent(of: size) == 5)
        #expect(StackAxis.horizontal.component(of: point) == 7)
        #expect(StackAxis.vertical.component(of: point) == 11)
        #expect(StackAxis.horizontal.point(2) == CGPoint(x: 2, y: 0))
        #expect(StackAxis.vertical.point(2) == CGPoint(x: 0, y: 2))
    }
}
