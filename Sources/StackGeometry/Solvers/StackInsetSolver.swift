import CoreGraphics

/// Which rule set the content insets are currently built from.
public enum StackInsetRegime: Equatable, Sendable {
    /// Every child is reachable in one drag. Used while pushing and popping.
    case unconstrained
    /// The first navigation step in each direction, or the full size when
    /// unfolding is unconstrained.
    case defaultConstraints
    /// The steps either side of where the stack is right now.
    case live(contentOffset: CGPoint, anchor: StackItemKey?)
}

public struct StackInsetResolution: Equatable, Sendable {
    public var insets: StackInsets

    public init(insets: StackInsets) {
        self.insets = insets
    }
}

/// Turns the stack's state into scroll-view content insets. The insets *are*
/// the scroll range, so this is what gates every drag.
public enum StackInsetSolver {

    /// Tolerance for comparing the offset against a just-rounded inset, where
    /// exact equality is a coin flip.
    static let equalityTolerance: CGFloat = 0.5

    public static func resolve(
        spec: StackSpec,
        regime: StackInsetRegime,
        constraints: StackNavigationConstraints = .all
    ) -> StackInsetResolution {
        switch regime {
        case .unconstrained:
            StackInsetResolution(insets: unconstrained(spec).rounded())
        case .defaultConstraints:
            StackInsetResolution(insets: defaultConstrained(spec, constraints).rounded())
        case let .live(contentOffset, anchor):
            live(spec, constraints, contentOffset: contentOffset, anchor: anchor)
        }
    }

    static func unconstrained(_ spec: StackSpec) -> StackInsets {
        var insets = StackInsets.zero
        for edge in StackPhysicalEdge.allCases {
            for frame in spec.finalFrames(at: edge) {
                switch edge {
                case .top:
                    insets.top = max(insets.top, abs(frame.minY))
                case .left:
                    insets.left = max(insets.left, abs(frame.minX))
                case .bottom:
                    insets.bottom = max(insets.bottom, frame.maxY - spec.containerSize.height)
                case .right:
                    insets.right = max(insets.right, frame.maxX - spec.containerSize.width)
                }
            }
        }
        return insets
    }

    static func defaultConstrained(
        _ spec: StackSpec,
        _ constraints: StackNavigationConstraints
    ) -> StackInsets {
        guard constraints.contains(.unfolding) else { return unconstrained(spec) }

        var insets = StackInsets.zero
        for edge in StackPhysicalEdge.allCases where !spec.items(at: edge).isEmpty {
            insets[edge] = abs(
                stepOffset(spec, edge: edge, index: 0, travel: .unfolding, contentOffset: .zero).value
            )
        }
        return insets
    }

    static func live(
        _ spec: StackSpec,
        _ constraints: StackNavigationConstraints,
        contentOffset: CGPoint,
        anchor: StackItemKey?
    ) -> StackInsetResolution {
        let items = anchor.map { spec.items(at: $0.edge) } ?? []
        guard contentOffset != .zero, let anchor, anchor.index < items.count else {
            return StackInsetResolution(insets: defaultConstrained(spec, constraints).rounded())
        }

        let edge = anchor.edge
        let maximumInset = spec.maximumInset(at: edge)
        var insets = StackInsets.zero

        if constraints.contains(.folding) {
            let folded = stepOffset(spec, edge: edge, index: anchor.index, travel: .folding, contentOffset: contentOffset).value
            switch edge {
            case .top:
                insets.top = -maximumInset.y
                insets.bottom = folded
            case .left:
                insets.left = -maximumInset.x
                insets.right = folded
            case .bottom:
                insets.bottom = maximumInset.y
                insets.top = -folded
            case .right:
                insets.right = maximumInset.x
                insets.left = -folded
            }
        }

        if constraints.contains(.unfolding) {
            let next = stepOffset(spec, edge: edge, index: anchor.index, travel: .unfolding, contentOffset: contentOffset)
            var value = abs(next.value)

            // Already sitting on the step: hop to the next sibling's first step,
            // unless that step is a block, which never releases.
            let travelled = abs(edge.axis.component(of: contentOffset))
            if abs(travelled - value) <= equalityTolerance,
               next.step.block != .unfolding,
               anchor.index < items.count - 1 {
                value = abs(
                    stepOffset(spec, edge: edge, index: anchor.index + 1, travel: .unfolding, contentOffset: contentOffset).value
                )
            }
            insets[edge] = value
        }

        return StackInsetResolution(insets: insets.rounded())
    }

    private static func stepOffset(
        _ spec: StackSpec,
        edge: StackPhysicalEdge,
        index: Int,
        travel: StackTravel,
        contentOffset: CGPoint
    ) -> (value: CGFloat, step: StackNavigationStep) {
        guard let edgeSpec = spec.edges[edge], index < edgeSpec.items.count else { return (0, .folded) }
        let result = StackStepSolver.nextStepOffset(
            steps: edgeSpec.items[index].steps,
            edge: edge,
            reversed: edgeSpec.isReversed,
            travel: travel,
            contentOffset: contentOffset,
            finalFrame: spec.finalFrames(at: edge)[index],
            maximumInset: spec.maximumInset(at: edge),
            containerSize: spec.containerSize,
            paginating: false
        )
        return (edge.axis.component(of: result.offset), result.step)
    }
}
