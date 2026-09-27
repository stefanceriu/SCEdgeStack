import CoreGraphics

/// Snaps the deceleration target onto a navigation step.
public enum StackPaginationSolver {

    /// The direction of travel implied by a velocity on `edge`'s axis.
    public static func travel(for velocity: CGPoint, edge: StackPhysicalEdge) -> StackTravel? {
        let value = edge.axis.component(of: velocity)
        guard value != 0 else { return nil }
        return (value < 0) == edge.isLeading ? .unfolding : .folding
    }

    /// When the scroll view is already past its insets the reported velocity
    /// collapses to almost nothing, so pagination has to be skipped and the
    /// target pinned to the bound. An internal `UIScrollView` behaviour.
    public static func bounceClamp(
        contentOffset: CGPoint,
        insets: StackInsets,
        target: CGPoint
    ) -> CGPoint? {
        var target = target
        if contentOffset.y < -insets.top {
            target.y = -insets.top.rounded()
        } else if contentOffset.x < -insets.left {
            target.x = -insets.left.rounded()
        } else if contentOffset.y > insets.bottom {
            target.y = insets.bottom.rounded()
        } else if contentOffset.x > insets.right {
            target.x = insets.right.rounded()
        } else {
            return nil
        }
        return target
    }

    public static func adjustedTarget(
        spec: StackSpec,
        target: CGPoint,
        velocity: CGPoint,
        pagingEnabled: Bool
    ) -> (offset: CGPoint, step: StackNavigationStep)? {
        guard pagingEnabled else { return nil }

        for edge in StackPhysicalEdge.allCases {
            guard let edgeSpec = spec.edges[edge], !edgeSpec.items.isEmpty else { continue }

            let maximumInset = spec.maximumInset(at: edge)
            var probe = target
            if edgeSpec.isReversed, containsProbe(target, edge: edge) {
                switch edge.axis {
                case .horizontal: probe.x = maximumInset.x - target.x
                case .vertical: probe.y = maximumInset.y - target.y
                }
            }

            let finalFrames = spec.finalFrames(at: edge)
            for index in edgeSpec.items.indices where hitBox(finalFrames[index], spec.containerSize).contains(probe) {
                let step = { (travel: StackTravel) in
                    StackStepSolver.nextStepOffset(
                        steps: edgeSpec.items[index].steps,
                        edge: edge,
                        reversed: edgeSpec.isReversed,
                        travel: travel,
                        contentOffset: target,
                        finalFrame: finalFrames[index],
                        maximumInset: maximumInset,
                        containerSize: spec.containerSize,
                        paginating: true
                    )
                }

                guard let travel = travel(for: velocity, edge: edge) else {
                    // No velocity: jump to whichever neighbouring step is closer.
                    let negative = step(edge.isLeading ? .unfolding : .folding)
                    let positive = step(edge.isLeading ? .folding : .unfolding)
                    let here = edge.axis.component(of: target)
                    let toNegative = abs(here - edge.axis.component(of: negative.offset))
                    let toPositive = abs(here - edge.axis.component(of: positive.offset))
                    return toNegative > toPositive ? positive : negative
                }

                return step(travel)
            }
        }

        return nil
    }

    /// A reversed edge's probe is mirrored only when the target is on that
    /// edge's side of the origin.
    private static func containsProbe(_ target: CGPoint, edge: StackPhysicalEdge) -> Bool {
        switch edge {
        case .top: target.y < 0
        case .left: target.x < 0
        case .bottom: target.y >= 0
        case .right: target.x >= 0
        }
    }

    /// The final frame translated into offset space, grown by a point so the
    /// maximum edges are inclusive.
    private static func hitBox(_ finalFrame: CGRect, _ container: CGSize) -> CGRect {
        var frame = finalFrame
        if frame.origin.x > 0 { frame.origin.x -= container.width }
        if frame.origin.y > 0 { frame.origin.y -= container.height }
        return frame.insetBy(dx: -0.5, dy: -0.5).offsetBy(dx: 0.5, dy: 0.5)
    }
}
