import CoreGraphics

/// Everything a layout needs to place one child.
///
/// The derived extents reduce each built-in layout's body to a handful of
/// one-liners.
public struct StackItemContext: Sendable {
    /// Already resolved against the layout direction.
    public let edge: StackPhysicalEdge
    public let index: Int
    public let siblingSizes: [CGSize]
    public let containerSize: CGSize
    public let contentOffset: CGPoint

    public init(
        edge: StackPhysicalEdge,
        index: Int,
        siblingSizes: [CGSize],
        containerSize: CGSize,
        contentOffset: CGPoint
    ) {
        self.edge = edge
        self.index = index
        self.siblingSizes = siblingSizes
        self.containerSize = containerSize
        self.contentOffset = contentOffset
    }

    public var axis: StackAxis { edge.axis }
    public var itemSize: CGSize { siblingSizes[index] }
    public var containerBounds: CGRect { CGRect(origin: .zero, size: containerSize) }

    /// Summed extent of the siblings closer to the root than this one.
    public var extentBefore: CGFloat {
        siblingSizes[..<index].reduce(0) { $0 + axis.extent(of: $1) }
    }

    /// `extentBefore` plus this child's own extent.
    public var extentThrough: CGFloat {
        extentBefore + axis.extent(of: itemSize)
    }

    /// Summed extent of every child on this edge.
    public var totalExtent: CGFloat {
        siblingSizes.reduce(0) { $0 + axis.extent(of: $1) }
    }

    public var maximumInset: CGPoint {
        axis.point(totalExtent * (edge.isLeading ? -1 : 1))
    }
}

/// Everything a layout needs to place the root.
public struct StackRootContext: Sendable {
    public let containerSize: CGSize
    public let contentOffset: CGPoint

    public init(containerSize: CGSize, contentOffset: CGPoint) {
        self.containerSize = containerSize
        self.contentOffset = contentOffset
    }

    public var containerBounds: CGRect { CGRect(origin: .zero, size: containerSize) }
}

/// Drives the frames and effects of one edge's children.
///
/// Frame and effect are split because the effect needs `visibleFraction`, which
/// is computed *from* the frames.
public protocol StackLayout: Sendable {
    /// Where the child sits when fully unfolded. Drives the scroll range.
    func finalFrame(_ ctx: StackItemContext) -> CGRect

    /// Where the child sits at `ctx.contentOffset`.
    func frame(_ ctx: StackItemContext, finalFrame: CGRect) -> CGRect

    func effect(_ ctx: StackItemContext, finalFrame: CGRect, visibleFraction: Double) -> StackEffect

    func rootFrame(_ ctx: StackRootContext) -> CGRect

    func rootEffect(_ ctx: StackRootContext, visibleFraction: Double) -> StackEffect

    /// Children are arranged from the container bounds towards the root rather
    /// than the other way around.
    var isReversed: Bool { get }

    /// Children are stacked on top of the root instead of underneath it.
    var stacksAboveRoot: Bool { get }
}

public extension StackLayout {
    /// The plain stacking arrangement: each child sits just beyond its siblings,
    /// off the edge.
    func finalFrame(_ ctx: StackItemContext) -> CGRect {
        var frame = CGRect(origin: .zero, size: ctx.itemSize)
        switch ctx.edge {
        case .top:
            frame.origin.y = -ctx.extentThrough
        case .left:
            frame.origin.x = -ctx.extentThrough
        case .bottom:
            frame.origin.y = ctx.containerSize.height + ctx.extentThrough - frame.height
        case .right:
            frame.origin.x = ctx.containerSize.width + ctx.extentThrough - frame.width
        }
        return frame
    }

    /// The child stays put and stretches across the cross axis.
    func frame(_ ctx: StackItemContext, finalFrame: CGRect) -> CGRect {
        stretchedAcrossCrossAxis(finalFrame, ctx)
    }

    /// Stretches `frame` to the container along the axis the edge does *not*
    /// travel on, leaving the travel axis alone.
    func stretchedAcrossCrossAxis(_ frame: CGRect, _ ctx: StackItemContext) -> CGRect {
        var frame = frame
        switch ctx.axis {
        case .vertical:
            frame.size.width = ctx.containerSize.width
            frame.size.height = ctx.itemSize.height
        case .horizontal:
            frame.size.height = ctx.containerSize.height
            frame.size.width = ctx.itemSize.width
        }
        return frame
    }

    func effect(_ ctx: StackItemContext, finalFrame: CGRect, visibleFraction: Double) -> StackEffect {
        .identity
    }

    func rootFrame(_ ctx: StackRootContext) -> CGRect {
        stacksAboveRoot
            ? CGRect(origin: ctx.contentOffset, size: ctx.containerSize)
            : ctx.containerBounds
    }

    func rootEffect(_ ctx: StackRootContext, visibleFraction: Double) -> StackEffect {
        .identity
    }

    var isReversed: Bool { false }
    var stacksAboveRoot: Bool { false }
}
