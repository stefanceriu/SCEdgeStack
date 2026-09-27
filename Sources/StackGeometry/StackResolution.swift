import CoreGraphics

/// Where a child sits, right now.
public struct StackPlacement: Equatable, Sendable {
    public var frame: CGRect
    public var effect: StackEffect
    /// `0...1`, occlusion aware, quantised to three decimals.
    public var visibleFraction: Double
    public var isVisible: Bool

    public init(
        frame: CGRect = .zero,
        effect: StackEffect = .identity,
        visibleFraction: Double = 0,
        isVisible: Bool = false
    ) {
        self.frame = frame
        self.effect = effect
        self.visibleFraction = visibleFraction
        self.isVisible = isVisible
    }
}

/// The output of one solve pass.
public struct StackResolution: Equatable, Sendable {
    public var contentOffset: CGPoint
    public var root: StackPlacement
    public var items: [StackItemKey: StackPlacement]
    /// Ordered by `(edge, index)`.
    public var visibleItems: [StackItemKey]

    public init(
        contentOffset: CGPoint = .zero,
        root: StackPlacement = StackPlacement(visibleFraction: 1, isVisible: true),
        items: [StackItemKey: StackPlacement] = [:],
        visibleItems: [StackItemKey] = []
    ) {
        self.contentOffset = contentOffset
        self.root = root
        self.items = items
        self.visibleItems = visibleItems
    }

    /// The deepest visible child, which anchors the live inset regime.
    public var anchor: StackItemKey? { visibleItems.last }
}
