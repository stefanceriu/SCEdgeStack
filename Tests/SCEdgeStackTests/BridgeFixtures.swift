#if os(iOS)
import UIKit
@testable import SCEdgeStack

enum Bridge {
    static let container = CGSize(width: 375, height: 812)

    @MainActor
    struct Harness {
        let engine: StackEngine
        let coordinator: StackScrollCoordinator
        let scrollView: PassthroughScrollView
        let edge: StackPhysicalEdge

        func key(_ index: Int) -> StackItemKey {
            StackItemKey(edge: edge, index: index)
        }

        var insets: UIEdgeInsets { scrollView.contentInset }
    }

    @MainActor
    static func harness(
        edge: StackEdge = .leading,
        extents: [CGFloat] = [200],
        steps: [[StackNavigationStep]] = [],
        configure: (inout StackConfiguration) -> Void = { _ in }
    ) -> Harness {
        let engine = StackEngine()
        var configuration = StackConfiguration()
        configure(&configuration)
        engine.configuration = configuration

        let coordinator = StackScrollCoordinator(engine: engine)
        let scrollView = PassthroughScrollView(frame: CGRect(origin: .zero, size: container))
        scrollView.delegate = coordinator
        coordinator.scrollView = scrollView
        scrollView.layoutIfNeeded()

        let physical = edge.resolved(.leftToRight)
        let descriptors = extents.indices.map { index in
            StackItemDescriptor(
                key: StackItemKey(edge: physical, index: index),
                token: StackItemToken(),
                id: .position(edge, index),
                size: physical.axis == .horizontal
                    ? CGSize(width: extents[index], height: container.height)
                    : CGSize(width: container.width, height: extents[index]),
                steps: index < steps.count ? steps[index] : []
            )
        }
        engine.commitMeasurements(containerSize: container, descriptors: descriptors)

        return Harness(engine: engine, coordinator: coordinator, scrollView: scrollView, edge: physical)
    }
}

#endif
