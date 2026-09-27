import CoreGraphics

private func clamp01(_ value: CGFloat) -> CGFloat {
    value.isFinite ? min(max(value, 0), 1) : 0
}

/// Children sit still off the edge and are progressively uncovered by the root.
public struct PlainStackLayout: StackLayout {
    public var stacksAboveRoot: Bool

    public init(stacksAboveRoot: Bool = false) {
        self.stacksAboveRoot = stacksAboveRoot
    }
}

/// Children travel at a fraction of the offset, trailing the root.
public struct ParallaxStackLayout: StackLayout {
    public var stacksAboveRoot: Bool

    public init(stacksAboveRoot: Bool = false) {
        self.stacksAboveRoot = stacksAboveRoot
    }

    public func frame(_ ctx: StackItemContext, finalFrame: CGRect) -> CGRect {
        var frame = stretchedAcrossCrossAxis(finalFrame, ctx)
        if stacksAboveRoot && ctx.index == 0 { return frame }

        let offset = ctx.contentOffset
        switch ctx.edge {
        case .top:
            let half = finalFrame.height / 2
            let ratio = (offset.y - half) / (finalFrame.minY - half)
            frame.origin.y = finalFrame.maxY - finalFrame.height * clamp01(ratio)
        case .left:
            let half = finalFrame.width / 2
            let ratio = (offset.x - half) / (finalFrame.minX - half)
            frame.origin.x = finalFrame.maxX - finalFrame.width * clamp01(ratio)
        case .bottom:
            let half = finalFrame.height / 2
            let ratio = (offset.y + half) / ((finalFrame.maxY - ctx.containerSize.height) + half)
            frame.origin.y = (finalFrame.minY - finalFrame.height) + finalFrame.height * clamp01(ratio)
        case .right:
            let half = finalFrame.width / 2
            let ratio = (offset.x + half) / ((finalFrame.maxX - ctx.containerSize.width) + half)
            frame.origin.x = (finalFrame.minX - finalFrame.width) + finalFrame.width * clamp01(ratio)
        }
        return frame
    }
}

/// Children track the offset one-for-one, clamped to their final frame.
public struct SlidingStackLayout: StackLayout {
    public var stacksAboveRoot: Bool

    public init(stacksAboveRoot: Bool = false) {
        self.stacksAboveRoot = stacksAboveRoot
    }

    public func frame(_ ctx: StackItemContext, finalFrame: CGRect) -> CGRect {
        var frame = stretchedAcrossCrossAxis(finalFrame, ctx)
        if stacksAboveRoot && ctx.index == 0 { return frame }

        let offset = ctx.contentOffset
        switch ctx.edge {
        case .top:
            frame.origin.y = min(finalFrame.maxY, max(finalFrame.minY, offset.y))
        case .left:
            frame.origin.x = min(finalFrame.maxX, max(finalFrame.minX, offset.x))
        case .bottom:
            let slid = ctx.containerSize.height - finalFrame.height + offset.y
            frame.origin.y = max(finalFrame.minY - finalFrame.height, min(finalFrame.minY, slid))
        case .right:
            let slid = ctx.containerSize.width - finalFrame.width + offset.x
            frame.origin.x = max(finalFrame.minX - finalFrame.width, min(finalFrame.minX, slid))
        }
        return frame
    }
}

/// Children stack above the root, which shrinks to make room.
public struct ResizingStackLayout: StackLayout {
    public init() {}

    public var stacksAboveRoot: Bool { true }

    public func rootFrame(_ ctx: StackRootContext) -> CGRect {
        let offset = ctx.contentOffset
        return CGRect(
            x: max(0, offset.x),
            y: max(0, offset.y),
            width: max(0, ctx.containerSize.width - abs(offset.x)),
            height: max(0, ctx.containerSize.height - abs(offset.y))
        )
    }
}

/// Children are arranged from the container bounds towards the root: the first
/// declared child ends up against the bounds, and each next one emerges from
/// beneath it.
public struct ReversedStackLayout: StackLayout {
    public var stacksAboveRoot: Bool

    public init(stacksAboveRoot: Bool = false) {
        self.stacksAboveRoot = stacksAboveRoot
    }

    public var isReversed: Bool { true }

    public func finalFrame(_ ctx: StackItemContext) -> CGRect {
        var frame = CGRect(origin: .zero, size: ctx.itemSize)
        switch ctx.edge {
        case .top:
            frame.origin.y = -ctx.totalExtent + ctx.extentBefore
        case .left:
            frame.origin.x = -ctx.totalExtent + ctx.extentBefore
        case .bottom:
            frame.origin.y = ctx.containerSize.height + ctx.totalExtent - ctx.extentThrough
        case .right:
            frame.origin.x = ctx.containerSize.width + ctx.totalExtent - ctx.extentThrough
        }
        return frame
    }

    public func frame(_ ctx: StackItemContext, finalFrame: CGRect) -> CGRect {
        var frame = stretchedAcrossCrossAxis(finalFrame, ctx)
        let offset = ctx.contentOffset
        switch ctx.edge {
        case .top:
            frame.origin.y = min(-ctx.itemSize.height, finalFrame.minY + ctx.totalExtent + offset.y)
        case .left:
            frame.origin.x = min(-ctx.itemSize.width, finalFrame.minX + ctx.totalExtent + offset.x)
        case .bottom:
            frame.origin.y = max(ctx.containerSize.height, finalFrame.minY - (ctx.totalExtent - offset.y))
        case .right:
            frame.origin.x = max(ctx.containerSize.width, finalFrame.minX - (ctx.totalExtent - offset.x))
        }
        return frame
    }
}
