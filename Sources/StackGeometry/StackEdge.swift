import CoreGraphics

/// The axis a stack edge travels along.
public enum StackAxis: Hashable, Sendable {
    case horizontal
    case vertical
}

/// The direction of travel along an edge's axis.
public enum StackTravel: Hashable, Sendable {
    /// Revealing more of the stacked content.
    case unfolding
    /// Hiding the stacked content, returning towards the root.
    case folding

    public var opposite: StackTravel {
        self == .unfolding ? .folding : .unfolding
    }
}

/// The writing direction used to resolve `leading` and `trailing`.
public enum StackLayoutDirection: Hashable, Sendable {
    case leftToRight
    case rightToLeft
}

/// The edge a child is declared on. `leading` and `trailing` resolve against the
/// ambient layout direction.
public enum StackEdge: Hashable, Sendable, CaseIterable {
    case top
    case leading
    case bottom
    case trailing

    public func resolved(_ direction: StackLayoutDirection) -> StackPhysicalEdge {
        switch self {
        case .top: .top
        case .bottom: .bottom
        case .leading: direction == .leftToRight ? .left : .right
        case .trailing: direction == .leftToRight ? .right : .left
        }
    }
}

/// A layout-direction resolved edge. All geometry is expressed in these terms.
public enum StackPhysicalEdge: Hashable, Sendable, CaseIterable {
    case top
    case left
    case bottom
    case right

    public var axis: StackAxis {
        switch self {
        case .top, .bottom: .vertical
        case .left, .right: .horizontal
        }
    }

    /// `true` for the edges sitting at the origin end of their axis.
    public var isLeading: Bool {
        self == .top || self == .left
    }

    /// The sign, along `axis`, in which the content offset moves while unfolding.
    public var unfoldingSign: CGFloat {
        isLeading ? -1 : 1
    }

    public func sign(for travel: StackTravel) -> CGFloat {
        travel == .unfolding ? unfoldingSign : -unfoldingSign
    }
}

public extension StackAxis {
    func extent(of size: CGSize) -> CGFloat {
        self == .horizontal ? size.width : size.height
    }

    func component(of point: CGPoint) -> CGFloat {
        self == .horizontal ? point.x : point.y
    }

    func point(_ value: CGFloat) -> CGPoint {
        self == .horizontal ? CGPoint(x: value, y: 0) : CGPoint(x: 0, y: value)
    }
}
