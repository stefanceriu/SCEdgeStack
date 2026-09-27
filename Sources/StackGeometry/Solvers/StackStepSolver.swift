import CoreGraphics

/// Resolves navigation steps into content offsets.
///
/// Every `edge x reversed` combination is affine in the step fraction `p`, and
/// the no-step fallback is the same formula at the extreme `p`. So the candidate
/// set is `steps` plus the implicit `{0, 1}`, run through one formula.
public enum StackStepSolver {

    /// Nudges a blocking step's offset so the stack stops short of it.
    ///
    /// Sitting exactly on a blocking step, the strict comparison below would
    /// otherwise skip past it and the inset would advance to the next step.
    static let blockEpsilon: CGFloat = 0.01

    /// The offset, along `edge.axis`, at which `finalFrame` is `fraction` unfolded.
    public static func offset(
        fraction p: Double,
        edge: StackPhysicalEdge,
        reversed: Bool,
        finalFrame f: CGRect,
        maximumInset m: CGPoint,
        containerSize c: CGSize
    ) -> CGFloat {
        let p = CGFloat(p)
        switch (edge, reversed) {
        case (.top, false):
            return f.maxY - f.height * p
        case (.top, true):
            return (m.y - f.maxY + f.height) - f.height * p
        case (.left, false):
            return f.maxX - f.width * p
        case (.left, true):
            return (m.x - f.maxX + f.width) - f.width * p
        case (.bottom, false):
            return (f.minY - c.height) + f.height * p
        case (.bottom, true):
            return (m.y - f.maxY + c.height) + f.height * p
        case (.right, false):
            return (f.minX - c.width) + f.width * p
        case (.right, true):
            return (m.x - f.maxX + c.width) + f.width * p
        }
    }

    /// The offset of the next stopping point past `contentOffset`, travelling in
    /// `travel`.
    ///
    /// The cross-axis component is zeroed.
    public static func nextStepOffset(
        steps: [StackNavigationStep],
        edge: StackPhysicalEdge,
        reversed: Bool,
        travel: StackTravel,
        contentOffset: CGPoint,
        finalFrame: CGRect,
        maximumInset: CGPoint,
        containerSize: CGSize,
        paginating: Bool
    ) -> (offset: CGPoint, step: StackNavigationStep) {
        let axis = edge.axis
        let sign = edge.sign(for: travel)
        let current = axis.component(of: contentOffset)

        // The offset is monotone in `p` with slope `edge.unfoldingSign`, so
        // walking the fractions in travel order walks the offsets in travel order.
        for step in steps.candidates(towards: travel) {
            var value = offset(
                fraction: step.fraction,
                edge: edge,
                reversed: reversed,
                finalFrame: finalFrame,
                maximumInset: maximumInset,
                containerSize: containerSize
            ).rounded()

            if !paginating, let blocked = step.blockedTravel {
                // Along the edge's own axis, with the edge's sign.
                value += edge.sign(for: blocked) * blockEpsilon
            }

            if (value - current) * sign > 0 {
                return (axis.point(value), step)
            }
        }

        // Nothing strictly ahead: pin to the far end of travel, which is the
        // same table at p = 1 / p = 0.
        let extreme = travel == .unfolding ? StackNavigationStep.full : .folded
        let value = offset(
            fraction: extreme.fraction,
            edge: edge,
            reversed: reversed,
            finalFrame: finalFrame,
            maximumInset: maximumInset,
            containerSize: containerSize
        ).rounded()
        return (axis.point(value), extreme)
    }
}
