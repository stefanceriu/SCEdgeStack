import CoreGraphics
import Testing
@testable import StackGeometry

@Suite("Built-in layouts")
struct LayoutTests {

    private func frames(
        _ layout: any StackLayout,
        _ edge: StackPhysicalEdge,
        sizes: [CGSize],
        offset: CGPoint
    ) -> [CGRect] {
        sizes.indices.map { index in
            let ctx = StackItemContext(
                edge: edge, index: index, siblingSizes: sizes,
                containerSize: Fixture.container, contentOffset: offset
            )
            return layout.frame(ctx, finalFrame: layout.finalFrame(ctx))
        }
    }

    private func finalFrames(
        _ layout: any StackLayout,
        _ edge: StackPhysicalEdge,
        sizes: [CGSize]
    ) -> [CGRect] {
        sizes.indices.map { index in
            layout.finalFrame(
                StackItemContext(
                    edge: edge, index: index, siblingSizes: sizes,
                    containerSize: Fixture.container, contentOffset: .zero
                )
            )
        }
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func plainChildrenSitOutsideTheContainerAtRest(edge: StackPhysicalEdge) {
        let sizes = (0..<3).map { _ in Fixture.child(100, on: edge) }
        for frame in frames(PlainStackLayout(), edge, sizes: sizes, offset: .zero) {
            let overlap = frame.intersection(CGRect(origin: .zero, size: Fixture.container))
            #expect(overlap.isNull || edge.axis.extent(of: overlap.size) == 0)
        }
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func plainChildrenAreAtTheirFinalFrameWhenFullyUnfolded(edge: StackPhysicalEdge) {
        let sizes = (0..<3).map { _ in Fixture.child(100, on: edge) }
        let maximumInset = edge.axis.point(300 * edge.unfoldingSign)
        let final = finalFrames(PlainStackLayout(), edge, sizes: sizes)

        for (index, frame) in frames(PlainStackLayout(), edge, sizes: sizes, offset: maximumInset).enumerated() {
            #expect(frame.origin == final[index].origin)
        }
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func plainChildrenTileWithoutGapsOrOverlaps(edge: StackPhysicalEdge) {
        let sizes = [80, 120, 60].map { Fixture.child(CGFloat($0), on: edge) }
        let final = finalFrames(PlainStackLayout(), edge, sizes: sizes)

        for index in 1..<sizes.count {
            let inner = final[index - 1]
            let outer = final[index]
            switch edge {
            case .top: #expect(outer.maxY == inner.minY)
            case .left: #expect(outer.maxX == inner.minX)
            case .bottom: #expect(outer.minY == inner.maxY)
            case .right: #expect(outer.minX == inner.maxX)
            }
        }
    }

    /// Parallax trails the offset: it covers less ground than the root does.
    @Test(arguments: StackPhysicalEdge.allCases)
    func parallaxMovesSlowerThanTheOffset(edge: StackPhysicalEdge) {
        let sizes = [Fixture.child(200, on: edge)]
        let layout = ParallaxStackLayout()
        var previous = frames(layout, edge, sizes: sizes, offset: .zero)[0]

        for tick in 1...40 {
            let travelled = CGFloat(tick) * 5
            let offset = edge.axis.point(travelled * edge.unfoldingSign)
            let frame = frames(layout, edge, sizes: sizes, offset: offset)[0]
            let moved = abs(edge.axis.component(of: frame.origin) - edge.axis.component(of: previous.origin))
            #expect(moved <= 5 + 1e-9)
            previous = frame
        }
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func slidingIsClampedToTheFinalFrame(edge: StackPhysicalEdge) {
        let sizes = [Fixture.child(200, on: edge)]
        let layout = SlidingStackLayout()
        let final = finalFrames(layout, edge, sizes: sizes)[0]

        for travelled in stride(from: CGFloat(-400), through: 400, by: 25) {
            let offset = edge.axis.point(travelled)
            let frame = frames(layout, edge, sizes: sizes, offset: offset)[0]
            let position = edge.axis.component(of: frame.origin)
            let bounds = [
                edge.axis.component(of: final.origin),
                edge.axis.component(of: final.origin) + edge.axis.extent(of: final.size) * edge.unfoldingSign * -1
            ].sorted()
            #expect(position >= bounds[0] - 1e-9 && position <= bounds[1] + 1e-9)
        }
    }

    /// Both layouts land on the final frame once the stack is fully unfolded,
    /// which is what makes them interchangeable at rest.
    @Test(arguments: StackPhysicalEdge.allCases)
    func parallaxAndSlidingAgreeAtBothEnds(edge: StackPhysicalEdge) {
        let sizes = [Fixture.child(200, on: edge)]
        let full = edge.axis.point(200 * edge.unfoldingSign)

        let parallax = frames(ParallaxStackLayout(), edge, sizes: sizes, offset: full)[0]
        let sliding = frames(SlidingStackLayout(), edge, sizes: sizes, offset: full)[0]
        let final = finalFrames(PlainStackLayout(), edge, sizes: sizes)[0]

        #expect(abs(edge.axis.component(of: parallax.origin) - edge.axis.component(of: final.origin)) < 1e-9)
        #expect(abs(edge.axis.component(of: sliding.origin) - edge.axis.component(of: final.origin)) < 1e-9)
    }

    @Test(arguments: StackPhysicalEdge.allCases)
    func resizingShrinksTheRootMonotonically(edge: StackPhysicalEdge) {
        let layout = ResizingStackLayout()
        var previousArea = Fixture.container.width * Fixture.container.height

        for tick in 0...40 {
            let offset = edge.axis.point(CGFloat(tick) * 5 * edge.unfoldingSign)
            let frame = layout.rootFrame(
                StackRootContext(containerSize: Fixture.container, contentOffset: offset)
            )
            let area = frame.width * frame.height
            #expect(area <= previousArea + 1e-9)
            #expect(frame.origin.x >= 0 && frame.origin.y >= 0)
            previousArea = area
        }
    }

    /// A reversed layout is the plain arrangement with the children swapped
    /// end for end.
    @Test(arguments: StackPhysicalEdge.allCases)
    func reversedIsPlainWithTheChildrenMirrored(edge: StackPhysicalEdge) {
        let sizes = [80, 120, 60].map { Fixture.child(CGFloat($0), on: edge) }
        let reversed = finalFrames(ReversedStackLayout(), edge, sizes: sizes)
        let mirrored = finalFrames(PlainStackLayout(), edge, sizes: sizes.reversed())

        for index in sizes.indices {
            #expect(reversed[index] == mirrored[sizes.count - 1 - index])
        }
    }

    @Test func contextDerivesExtentsFromSiblingSizes() {
        let sizes = [80, 120, 60].map { Fixture.child(CGFloat($0), on: .left) }
        let ctx = StackItemContext(
            edge: .left, index: 1, siblingSizes: sizes,
            containerSize: Fixture.container, contentOffset: .zero
        )
        #expect(ctx.extentBefore == 80)
        #expect(ctx.extentThrough == 200)
        #expect(ctx.totalExtent == 260)
        #expect(ctx.maximumInset == CGPoint(x: -260, y: 0))
        #expect(ctx.itemSize == sizes[1])
    }

    @Test func crossAxisIsStretchedToTheContainer() {
        for edge in StackPhysicalEdge.allCases {
            let sizes = [CGSize(width: 40, height: 40)]
            let frame = frames(PlainStackLayout(), edge, sizes: sizes, offset: .zero)[0]
            if edge.axis == .horizontal {
                #expect(frame.height == Fixture.container.height)
                #expect(frame.width == 40)
            } else {
                #expect(frame.width == Fixture.container.width)
                #expect(frame.height == 40)
            }
        }
    }
}
