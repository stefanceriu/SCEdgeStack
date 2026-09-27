import CoreGraphics

/// Addresses a child inside the engine's caches.
public struct StackItemKey: Hashable, Sendable, Comparable {
    public let edge: StackPhysicalEdge
    public let index: Int

    public init(edge: StackPhysicalEdge, index: Int) {
        self.edge = edge
        self.index = index
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        let order = StackPhysicalEdge.allCases
        let l = order.firstIndex(of: lhs.edge)!
        let r = order.firstIndex(of: rhs.edge)!
        return (l, lhs.index) < (r, rhs.index)
    }
}

/// Everything the solvers need to know about a single child.
public struct StackItemSpec: Equatable, Sendable {
    public var size: CGSize
    public var steps: [StackNavigationStep]

    public init(size: CGSize, steps: [StackNavigationStep] = []) {
        self.size = size
        self.steps = steps
    }
}

/// Everything the solvers need to know about one edge of the stack.
public struct StackEdgeSpec: Sendable {
    public var items: [StackItemSpec]
    public var layout: any StackLayout

    public init(items: [StackItemSpec] = [], layout: any StackLayout = PlainStackLayout()) {
        self.items = items
        self.layout = layout
    }

    public var isReversed: Bool { layout.isReversed }
    public var stacksAboveRoot: Bool { layout.stacksAboveRoot }
}

/// A complete, platform-agnostic description of the stack.
public struct StackSpec: Sendable {
    public var containerSize: CGSize
    public var edges: [StackPhysicalEdge: StackEdgeSpec]

    public init(containerSize: CGSize, edges: [StackPhysicalEdge: StackEdgeSpec] = [:]) {
        self.containerSize = containerSize
        self.edges = edges
    }

    public func items(at edge: StackPhysicalEdge) -> [StackItemSpec] {
        edges[edge]?.items ?? []
    }

    public var containerBounds: CGRect {
        CGRect(origin: .zero, size: containerSize)
    }

    /// The signed offset at which every child on `edge` is fully unfolded.
    public func maximumInset(at edge: StackPhysicalEdge) -> CGPoint {
        let total = items(at: edge).reduce(CGFloat.zero) { $0 + edge.axis.extent(of: $1.size) }
        return edge.axis.point(total * (edge.isLeading ? -1 : 1))
    }

    /// The final frames for every child on `edge`, in scroll-view coordinates.
    public func finalFrames(at edge: StackPhysicalEdge) -> [CGRect] {
        guard let spec = edges[edge] else { return [] }
        let sizes = spec.items.map(\.size)
        return spec.items.indices.map { index in
            spec.layout.finalFrame(
                StackItemContext(
                    edge: edge,
                    index: index,
                    siblingSizes: sizes,
                    containerSize: containerSize,
                    contentOffset: .zero
                )
            )
        }
    }
}

/// Scroll-view content insets, in the sign convention UIKit uses.
public struct StackInsets: Equatable, Sendable {
    public var top: CGFloat
    public var left: CGFloat
    public var bottom: CGFloat
    public var right: CGFloat

    public init(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }

    public static let zero = StackInsets()

    public subscript(edge: StackPhysicalEdge) -> CGFloat {
        get {
            switch edge {
            case .top: top
            case .left: left
            case .bottom: bottom
            case .right: right
            }
        }
        set {
            switch edge {
            case .top: top = newValue
            case .left: left = newValue
            case .bottom: bottom = newValue
            case .right: right = newValue
            }
        }
    }

    /// Rounds to whole points. The
    /// rounding is load-bearing: the live regime compares the offset against it.
    public func rounded() -> StackInsets {
        StackInsets(top: top.rounded(), left: left.rounded(), bottom: bottom.rounded(), right: right.rounded())
    }
}
