import CoreGraphics
import StackGeometry

enum Fixture {
    static let container = CGSize(width: 375, height: 812)

    static func spec(
        _ edge: StackPhysicalEdge,
        sizes: [CGSize],
        steps: [[StackNavigationStep]] = [],
        layout: any StackLayout = PlainStackLayout(),
        container: CGSize = Fixture.container
    ) -> StackSpec {
        let items = sizes.indices.map { index in
            StackItemSpec(size: sizes[index], steps: index < steps.count ? steps[index] : [])
        }
        return StackSpec(containerSize: container, edges: [edge: StackEdgeSpec(items: items, layout: layout)])
    }

    /// A square-ish child sized so it makes sense on either axis.
    static func child(_ extent: CGFloat, on edge: StackPhysicalEdge, container: CGSize = Fixture.container) -> CGSize {
        edge.axis == .horizontal
            ? CGSize(width: extent, height: container.height)
            : CGSize(width: container.width, height: extent)
    }

    static func nextStep(
        _ spec: StackSpec,
        edge: StackPhysicalEdge,
        index: Int,
        travel: StackTravel,
        contentOffset: CGPoint,
        paginating: Bool = false
    ) -> (offset: CGPoint, step: StackNavigationStep) {
        let edgeSpec = spec.edges[edge]!
        return StackStepSolver.nextStepOffset(
            steps: edgeSpec.items[index].steps,
            edge: edge,
            reversed: edgeSpec.isReversed,
            travel: travel,
            contentOffset: contentOffset,
            finalFrame: spec.finalFrames(at: edge)[index],
            maximumInset: spec.maximumInset(at: edge),
            containerSize: spec.containerSize,
            paginating: paginating
        )
    }
}

/// A deterministic generator, so a failing sweep is reproducible from its seed.
struct Rng {
    private var state: UInt64

    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + Int(next() % UInt64(range.count))
    }
}
