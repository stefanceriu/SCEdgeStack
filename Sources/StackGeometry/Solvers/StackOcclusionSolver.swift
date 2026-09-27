import CoreGraphics

/// Solves every child's frame, visible fraction and effect for one content offset.
public enum StackOcclusionSolver {

    /// Quantises to three decimals, which damps per-tick churn into no-op writes.
    static func quantise(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return (value * 1000).rounded() / 1000
    }

    public static func resolve(
        spec: StackSpec,
        contentOffset: CGPoint,
        previousActiveEdge: StackPhysicalEdge? = nil
    ) -> StackResolution {
        let container = spec.containerSize
        let scrollBounds = CGRect(origin: contentOffset, size: container)
        let activeEdge = activeEdge(for: contentOffset) ?? previousActiveEdge
        let activeLayout = activeEdge.flatMap { spec.edges[$0]?.layout }

        let rootContext = StackRootContext(containerSize: container, contentOffset: contentOffset)
        let rootFrame = activeLayout?.rootFrame(rootContext) ?? spec.containerBounds
        var rootRemainder = scrollBounds.intersection(rootFrame)
        if rootRemainder.isNull { rootRemainder = .zero }

        var placements: [StackItemKey: StackPlacement] = [:]
        var visible: [StackItemKey] = []

        if let chopEdge = CGRect.edge(fromOffset: contentOffset) {
            for edge in StackPhysicalEdge.allCases {
                guard let edgeSpec = spec.edges[edge], !edgeSpec.items.isEmpty else { continue }

                let layout = edgeSpec.layout
                let sizes = edgeSpec.items.map(\.size)
                let maximumInset = spec.maximumInset(at: edge)

                // How much unobstructed space this edge's children can be seen through.
                let occluder = edgeSpec.stacksAboveRoot
                    ? scrollBounds.intersection(spec.containerBounds)
                    : scrollBounds.intersection(rootFrame)
                var remainder = scrollBounds.subtracting(occluder, edge: chopEdge)

                var currentFrames: [CGRect] = []

                for index in edgeSpec.items.indices {
                    let context = StackItemContext(
                        edge: edge,
                        index: index,
                        siblingSizes: sizes,
                        containerSize: container,
                        contentOffset: contentOffset
                    )
                    let finalFrame = layout.finalFrame(context)
                    let frame = layout.frame(context, finalFrame: finalFrame)
                    currentFrames.append(frame)

                    var adjusted = frame
                    if index > 0 {
                        if edgeSpec.isReversed {
                            adjusted = reversedAdjustment(
                                adjusted,
                                edge: edge,
                                index: index,
                                sizes: sizes,
                                maximumInset: maximumInset,
                                container: container
                            )
                        } else {
                            for previous in currentFrames[..<index] {
                                adjusted = adjusted.subtracting(previous, edge: chopEdge)
                            }
                        }
                    }

                    let intersection = remainder.intersection(adjusted)
                    let extent = edge.axis.extent(of: intersection.isNull ? .zero : intersection.size)
                    let isVisible = extent > 0

                    var fraction = 0.0
                    if isVisible {
                        let total = edge.axis.extent(of: frame.size)
                        fraction = total > 0 ? quantise(extent / total) : 0

                        remainder = remainder.subtracting(remainder.intersection(adjusted), edge: chopEdge)
                        if edgeSpec.stacksAboveRoot {
                            rootRemainder = rootRemainder.subtracting(
                                rootRemainder.intersection(adjusted), edge: chopEdge
                            )
                        }
                    }

                    let key = StackItemKey(edge: edge, index: index)
                    placements[key] = StackPlacement(
                        frame: frame,
                        effect: layout.effect(context, finalFrame: finalFrame, visibleFraction: fraction),
                        visibleFraction: fraction,
                        isVisible: isVisible
                    )
                    if isVisible { visible.append(key) }
                }
            }
        } else {
            // Centred on the root: nothing is uncovered, but every child still
            // needs a frame.
            for edge in StackPhysicalEdge.allCases {
                guard let edgeSpec = spec.edges[edge], !edgeSpec.items.isEmpty else { continue }
                let sizes = edgeSpec.items.map(\.size)
                for index in edgeSpec.items.indices {
                    let context = StackItemContext(
                        edge: edge,
                        index: index,
                        siblingSizes: sizes,
                        containerSize: container,
                        contentOffset: contentOffset
                    )
                    let finalFrame = edgeSpec.layout.finalFrame(context)
                    placements[StackItemKey(edge: edge, index: index)] = StackPlacement(
                        frame: edgeSpec.layout.frame(context, finalFrame: finalFrame),
                        effect: edgeSpec.layout.effect(context, finalFrame: finalFrame, visibleFraction: 0),
                        visibleFraction: 0,
                        isVisible: false
                    )
                }
            }
        }

        let hasVertical = !spec.items(at: .top).isEmpty || !spec.items(at: .bottom).isEmpty
        let hasHorizontal = !spec.items(at: .left).isEmpty || !spec.items(at: .right).isEmpty

        var rootVisible = hasHorizontal && rootRemainder.width > 0
        rootVisible = rootVisible || (hasVertical && rootRemainder.height > 0)
        rootVisible = rootVisible || (!hasHorizontal && !hasVertical)

        var rootFraction = 0.0
        if rootVisible {
            if hasVertical, rootFrame.height > 0 {
                rootFraction = quantise(rootRemainder.height / rootFrame.height)
            } else if hasHorizontal, rootFrame.width > 0 {
                rootFraction = quantise(rootRemainder.width / rootFrame.width)
            } else {
                rootFraction = 1
            }
        }

        return StackResolution(
            contentOffset: contentOffset,
            root: StackPlacement(
                frame: rootFrame,
                effect: activeLayout?.rootEffect(rootContext, visibleFraction: rootFraction) ?? .identity,
                visibleFraction: rootFraction,
                isVisible: rootVisible
            ),
            items: placements,
            visibleItems: visible.sorted()
        )
    }

    /// The edge whose layout drives the root, picked from the sign of the offset.
    public static func activeEdge(for offset: CGPoint) -> StackPhysicalEdge? {
        if offset.y < 0 { return .top }
        if offset.x < 0 { return .left }
        if offset.y > 0 { return .bottom }
        if offset.x > 0 { return .right }
        return nil
    }

    /// A reversed layout draws its children in the opposite order, so the frame
    /// used for occlusion has to be pushed back to where a plain stack would
    /// have put it.
    private static func reversedAdjustment(
        _ frame: CGRect,
        edge: StackPhysicalEdge,
        index: Int,
        sizes: [CGSize],
        maximumInset: CGPoint,
        container: CGSize
    ) -> CGRect {
        var frame = frame
        let axis = edge.axis
        switch edge {
        case .top:
            let remaining = sizes[(index + 1)...].reduce(CGFloat.zero) { $0 + axis.extent(of: $1) }
            frame.origin.y = maximumInset.y + remaining
        case .left:
            let remaining = sizes[(index + 1)...].reduce(CGFloat.zero) { $0 + axis.extent(of: $1) }
            frame.origin.x = maximumInset.x + remaining
        case .bottom:
            let remaining = sizes[index...].reduce(CGFloat.zero) { $0 + axis.extent(of: $1) }
            frame.origin.y = container.height + maximumInset.y - remaining
        case .right:
            let remaining = sizes[index...].reduce(CGFloat.zero) { $0 + axis.extent(of: $1) }
            frame.origin.x = container.width + maximumInset.x - remaining
        }
        return frame
    }
}
