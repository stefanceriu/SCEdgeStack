import CoreGraphics

public extension CGRect {
    /// Chops `other` off `self` from `edge` and returns what is left.
    ///
    /// Equal rects collapse to `.zero`; a null intersection
    /// leaves `self` untouched.
    func subtracting(_ other: CGRect, edge: CGRectEdge) -> CGRect {
        if self == other { return .zero }

        let intersection = self.intersection(other)
        if intersection.isNull { return self }

        let chop = (edge == .minXEdge || edge == .maxXEdge) ? intersection.width : intersection.height
        return divided(atDistance: chop, from: edge).remainder
    }

    /// The edge the stacked content is chopped from, given the current offset.
    ///
    /// `nil` for a centred stack.
    static func edge(fromOffset offset: CGPoint) -> CGRectEdge? {
        if offset.x > 0 { return .minXEdge }
        if offset.x < 0 { return .maxXEdge }
        if offset.y > 0 { return .minYEdge }
        if offset.y < 0 { return .maxYEdge }
        return nil
    }
}
