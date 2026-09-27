#if os(iOS)
import SwiftUI
import StackGeometry

/// Hosts the whole SwiftUI subtree inside the hidden scroll view.
///
/// The content lives *inside* the scroll view rather than beside it, which is
/// what makes hit-testing work: an overlay scroll view with no subviews has to
/// swallow touches in order to receive pans, and that kills every `Button` in a
/// child.
struct StackScrollHost<Content: View>: UIViewControllerRepresentable {
    let engine: StackEngine
    let configuration: StackConfiguration
    let layoutDirection: StackLayoutDirection
    let content: Content

    func makeCoordinator() -> StackScrollCoordinator {
        StackScrollCoordinator(engine: engine)
    }

    func makeUIViewController(context: Context) -> StackScrollContainerController {
        let coordinator = context.coordinator
        let controller = StackScrollContainerController()

        let scrollView = controller.scrollView
        scrollView.delegate = coordinator
        coordinator.scrollView = scrollView
        scrollView.onBoundsSizeChange = { [weak coordinator] size in
            coordinator?.boundsSizeChanged(size)
        }

        let host = UIHostingController(rootView: content)
        host.safeAreaRegions = []
        host.sizingOptions = []
        host.view.backgroundColor = .clear
        coordinator.hostingController = host

        controller.addChild(host)
        scrollView.addSubview(host.view)
        host.didMove(toParent: controller)
        scrollView.contentHost = host.view

        return controller
    }

    func updateUIViewController(_ controller: StackScrollContainerController, context: Context) {
        let coordinator = context.coordinator

        engine.configuration = configuration
        engine.layoutDirection = layoutDirection

        let scrollView = controller.scrollView
        scrollView.decelerationRate = configuration.decelerationRate
        scrollView.dragActivation = configuration.dragActivation
        scrollView.allowsSimultaneousGestures = configuration.simultaneousGestures

        (coordinator.hostingController as? UIHostingController<Content>)?.rootView = content
    }
}

/// A plain wrapper around the scroll view.
///
/// The wrapper is not ceremony: with the scroll view as the controller's own
/// view, UIKit's `_adjustContentOffsetIfNecessary` fires and moves an offset
/// that *is* the whole navigation state.
final class StackScrollContainerController: UIViewController {
    let scrollView = PassthroughScrollView()

    override func loadView() {
        view = UIView()
        view.backgroundColor = .clear
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrollView)
    }
}
#endif
