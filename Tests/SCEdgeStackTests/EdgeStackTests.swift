#if os(iOS)
import SwiftUI
import Testing
@testable import SCEdgeStack

/// Collects what a hosted stack reports, for assertions from outside it.
@MainActor
private final class Probe {
    var proxy: StackProxy?
    var frames: [String: CGRect] = [:]
    var offsets: [CGPoint] = []
    var visibility: [(StackItemID, Bool)] = []
    var directions: [String: LayoutDirection] = [:]
    var steps: [(StackItemID, StackNavigationStep)] = []
    var fractions: [String: Double] = [:]
    var itemIDs: [String: StackItemID] = [:]

    var engine: StackEngine { proxy!.engine }
}

private extension View {
    func reportFrame(_ name: String, to probe: Probe) -> some View {
        onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { probe.frames[name] = $0 }
            .background(DirectionReader(name: name, probe: probe))
    }
}

private struct DirectionReader: View {
    let name: String
    let probe: Probe
    @Environment(\.layoutDirection) private var direction

    var body: some View {
        Color.clear.onAppear { probe.directions[name] = direction }
    }
}

/// A real `EdgeStack` in a real window.
@MainActor
private final class Host {
    let window = UIWindow(frame: CGRect(origin: .zero, size: Bridge.container))

    init(_ view: some View) {
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
    }

    /// Runs layout passes until `condition` holds. Measurement commits and
    /// frame reports land on later turns of the run loop, never inline.
    @discardableResult
    func settle(until condition: () -> Bool) async -> Bool {
        for _ in 0..<100 {
            window.layoutIfNeeded()
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return false
    }

    func close() { window.isHidden = true }
}

/// Reports the enclosing child's own placement, read the way a consumer would.
private struct FractionReader: View {
    let name: String
    let probe: Probe
    @Environment(\.stackItem) private var item

    var body: some View {
        Color.clear.onChange(of: item?.visibleFraction, initial: true) { _, fraction in
            probe.fractions[name] = fraction
            probe.itemIDs[name] = item?.id
        }
    }
}

/// The labels VoiceOver would reach, walked through UIKit's accessibility tree.
@MainActor
private func accessibilityLabels(in object: Any, depth: Int = 0) -> [String] {
    guard depth < 40, let element = object as? NSObject else { return [] }
    var labels: [String] = []
    if element.isAccessibilityElement, let label = element.accessibilityLabel { labels.append(label) }
    if let children = element.accessibilityElements {
        for child in children { labels += accessibilityLabels(in: child, depth: depth + 1) }
    } else if let view = object as? UIView, !view.accessibilityElementsHidden {
        for subview in view.subviews { labels += accessibilityLabels(in: subview, depth: depth + 1) }
    }
    return labels
}

private func near(_ a: CGFloat?, _ b: CGFloat) -> Bool {
    guard let a else { return false }
    return abs(a - b) < 0.5
}

@Suite("EdgeStack in a window", .timeLimit(.minutes(1)))
@MainActor
struct EdgeStackTests {

    /// Root plus one leading child, 200 wide, reporting both frames.
    private func menuStack(_ probe: Probe, direction: LayoutDirection = .leftToRight) -> some View {
        StackReader { proxy in
            EdgeStack {
                Color.blue.reportFrame("root", to: probe)
            } children: {
                Color.red
                    .reportFrame("menu", to: probe)
                    .stackEdge(.leading)
                    .stackID("menu")
                    .stackExtent(200)
            }
            .onStackOffsetChange { probe.offsets.append($0) }
            .onStackVisibilityChange { probe.visibility.append(($0, $1)) }
            .onStackStep { probe.steps.append(($0, $1)) }
            .onAppear { probe.proxy = proxy }
        }
        .environment(\.layoutDirection, direction)
    }

    private func mounted(_ probe: Probe, _ host: Host) async -> Bool {
        await host.settle { probe.proxy?.placement(for: StackItemID("menu")) != nil }
    }

    // MARK: - Measurement

    @Test func aChildWithoutAnExtentIsMeasuredAndAnExtentWins() async {
        let probe = Probe()
        let host = Host(
            StackReader { proxy in
                EdgeStack {
                    Color.blue
                } children: {
                    Color.red.frame(width: 180)
                        .stackEdge(.leading)
                    Color.green.frame(width: 300)
                        .stackEdge(.leading)
                        .stackExtent(120)
                }
                .onAppear { probe.proxy = proxy }
            }
        )
        defer { host.close() }

        let measured = await host.settle { probe.proxy?.engine.spec.items(at: .left).count == 2 }
        #expect(measured)
        #expect(probe.engine.spec.items(at: .left).map(\.size.width) == [180, 120])
        #expect(probe.engine.spec.items(at: .left).allSatisfy { $0.size.height == Bridge.container.height })
    }

    @Test func declarationOrderAndIDsAddressTheChildren() async {
        let probe = Probe()
        let host = Host(
            StackReader { proxy in
                EdgeStack {
                    Color.blue
                } children: {
                    Color.red.stackEdge(.leading).stackID("a").stackExtent(100)
                    Color.green.stackEdge(.leading).stackID("b").stackExtent(100)
                    Color.yellow.stackEdge(.trailing).stackExtent(100)
                }
                .onAppear { probe.proxy = proxy }
            }
        )
        defer { host.close() }

        await host.settle { probe.proxy?.engine.spec.items(at: .right).count == 1 }
        #expect(probe.engine.key(for: StackItemID("a")) == StackItemKey(edge: .left, index: 0))
        #expect(probe.engine.key(for: StackItemID("b")) == StackItemKey(edge: .left, index: 1))
        #expect(probe.engine.key(for: .position(.trailing, 0)) == StackItemKey(edge: .right, index: 0))
    }

    // MARK: - Placement

    @Test func revealPlacesTheChildAndMovesTheRoot() async {
        let probe = Probe()
        let host = Host(menuStack(probe))
        defer { host.close() }
        #expect(await mounted(probe, host))

        let folded = await host.settle { probe.frames["menu"] != nil && probe.frames["root"] != nil }
        #expect(folded)
        #expect((probe.frames["menu"]?.maxX ?? 1) <= 0.5, "folded child sits off the leading edge")
        #expect(near(probe.frames["root"]?.minX, 0))

        #expect(await probe.proxy!.reveal("menu", animation: .immediate))

        let placed = await host.settle { near(probe.frames["menu"]?.minX, 0) }
        #expect(placed, "revealed child sits at the leading edge, got \(String(describing: probe.frames["menu"]))")
        #expect(near(probe.frames["menu"]?.width, 200))
        #expect(near(probe.frames["root"]?.minX, 200), "plain layout pushes the root aside")
    }

    // MARK: - Proxy

    @Test func revealAndFoldMoveTheOffset() async {
        let probe = Probe()
        let host = Host(menuStack(probe))
        defer { host.close() }
        #expect(await mounted(probe, host))
        let proxy = probe.proxy!

        #expect(await proxy.reveal("menu", animation: .immediate))
        #expect(proxy.contentOffset == CGPoint(x: -200, y: 0))
        #expect(proxy.visibleItems == [StackItemID("menu")])
        #expect(proxy.placement(for: StackItemID("menu"))?.visibleFraction == 1)

        #expect(await proxy.fold(animation: .immediate))
        #expect(proxy.contentOffset == .zero)
        #expect(proxy.visibleItems.isEmpty)
    }

    @Test func revealToAStepStopsPartWay() async {
        let probe = Probe()
        let host = Host(menuStack(probe))
        defer { host.close() }
        #expect(await mounted(probe, host))

        #expect(await probe.proxy!.reveal("menu", to: .init(0.5), animation: .immediate))
        #expect(probe.proxy!.contentOffset == CGPoint(x: -100, y: 0))
        #expect(probe.proxy!.placement(for: StackItemID("menu"))?.visibleFraction == 0.5)
    }

    @Test func revealingAnUnknownChildFailsAndStaysPut() async {
        let probe = Probe()
        let host = Host(menuStack(probe))
        defer { host.close() }
        #expect(await mounted(probe, host))

        #expect(await probe.proxy!.reveal("nope", animation: .immediate) == false)
        #expect(probe.proxy!.contentOffset == .zero)
        #expect(probe.proxy!.placement(for: StackItemID("nope")) == nil)
    }

    @Test func anAnimatedRevealLandsOnItsTarget() async {
        let probe = Probe()
        let host = Host(menuStack(probe))
        defer { host.close() }
        #expect(await mounted(probe, host))

        #expect(await probe.proxy!.reveal("menu", animation: .init(curve: .elasticOut, duration: 0.1)))
        #expect(probe.proxy!.contentOffset == CGPoint(x: -200, y: 0))
        #expect(probe.offsets.count > 2, "an animation reports intermediate offsets")
    }

    // MARK: - Callbacks

    @Test func callbacksReportOffsetsAndVisibilityEdges() async {
        let probe = Probe()
        let host = Host(menuStack(probe))
        defer { host.close() }
        #expect(await mounted(probe, host))

        await probe.proxy!.reveal("menu", animation: .immediate)
        await probe.proxy!.fold(animation: .immediate)

        #expect(probe.offsets.contains(CGPoint(x: -200, y: 0)))
        #expect(probe.offsets.last == .zero)
        #expect(probe.visibility.map(\.0) == [StackItemID("menu"), StackItemID("menu")])
        #expect(probe.visibility.map(\.1) == [true, false])
    }

    @Test func programmaticNavigationReportsTheStepItLandsOn() async {
        let probe = Probe()
        let host = Host(menuStack(probe))
        defer { host.close() }
        #expect(await mounted(probe, host))

        await probe.proxy!.reveal("menu", to: .init(0.5), animation: .immediate)
        await probe.proxy!.fold(animation: .immediate)

        #expect(probe.steps.map(\.0) == [StackItemID("menu"), .root])
        #expect(probe.steps.map(\.1) == [.init(0.5), .folded])
    }

    @Test func aStoppedNavigationReportsNoStep() async {
        let probe = Probe()
        let host = Host(menuStack(probe))
        defer { host.close() }
        #expect(await mounted(probe, host))

        let proxy = probe.proxy!
        async let finished = proxy.reveal("menu", animation: .init(curve: .linear, duration: 5))
        try? await Task.sleep(for: .milliseconds(50))
        proxy.stopAnimation()

        #expect(await finished == false)
        #expect(probe.steps.isEmpty)
    }

    // MARK: - Per-child state

    /// Each child reads its own placement from the environment, not a
    /// sibling's and not the root's.
    @Test func everyChildSeesItsOwnVisibleFraction() async {
        let probe = Probe()
        let host = Host(
            StackReader { proxy in
                EdgeStack {
                    Color.blue
                } children: {
                    FractionReader(name: "a", probe: probe).stackEdge(.leading).stackID("a").stackExtent(100)
                    FractionReader(name: "b", probe: probe).stackEdge(.leading).stackID("b").stackExtent(100)
                }
                .onAppear { probe.proxy = proxy }
            }
        )
        defer { host.close() }
        await host.settle { probe.proxy?.placement(for: StackItemID("b")) != nil }

        #expect(await probe.proxy!.reveal("a", animation: .immediate))
        let first = await host.settle { probe.fractions["a"] == 1 && probe.fractions["b"] == 0 }
        #expect(first, "got \(probe.fractions)")

        #expect(await probe.proxy!.reveal("b", to: .init(0.5), animation: .immediate))
        let second = await host.settle { probe.fractions["a"] == 1 && probe.fractions["b"] == 0.5 }
        #expect(second, "got \(probe.fractions)")

        #expect(probe.itemIDs["a"] == StackItemID("a"))
        #expect(probe.itemIDs["b"] == StackItemID("b"))
    }

    // MARK: - Accessibility

    @Test func onlyVisibleChildrenReachVoiceOver() async {
        let probe = Probe()
        let host = Host(
            StackReader { proxy in
                EdgeStack {
                    Text("Root")
                } children: {
                    Text("Menu").stackEdge(.leading).stackID("menu").stackExtent(200)
                }
                .onAppear { probe.proxy = proxy }
            }
        )
        defer { host.close() }
        #expect(await mounted(probe, host))

        let folded = await host.settle { accessibilityLabels(in: host.window) == ["Root"] }
        #expect(folded, "got \(accessibilityLabels(in: host.window))")

        #expect(await probe.proxy!.reveal("menu", animation: .immediate))
        let revealed = await host.settle { Set(accessibilityLabels(in: host.window)) == ["Menu", "Root"] }
        #expect(revealed, "got \(accessibilityLabels(in: host.window))")

        #expect(await probe.proxy!.fold(animation: .immediate))
        let refolded = await host.settle { accessibilityLabels(in: host.window) == ["Root"] }
        #expect(refolded, "got \(accessibilityLabels(in: host.window))")
    }

    // MARK: - Nesting

    /// A stack inside a child gets its own engine instead of sharing the
    /// outer one, so neither stack's children leak into the other.
    @Test func aNestedStackIsIndependentOfTheOuterOne() async {
        let probe = Probe()
        let host = Host(
            StackReader { proxy in
                EdgeStack {
                    Color.blue
                } children: {
                    EdgeStack {
                        Color.green
                    } children: {
                        Color.yellow.stackEdge(.top).stackExtent(100)
                    }
                    .reportFrame("menu", to: probe)
                    .stackEdge(.leading)
                    .stackID("menu")
                    .stackExtent(200)
                }
                .onAppear { probe.proxy = proxy }
            }
        )
        defer { host.close() }
        #expect(await mounted(probe, host))

        // Give the inner stack time to measure and commit, wherever it commits to.
        for _ in 0..<20 {
            host.window.layoutIfNeeded()
            try? await Task.sleep(for: .milliseconds(10))
        }

        #expect(probe.engine.spec.items(at: .left).count == 1)
        #expect(probe.engine.spec.items(at: .top).isEmpty, "the inner stack's child leaked into the outer stack")

        #expect(await probe.proxy!.reveal("menu", animation: .immediate))
        #expect(probe.proxy!.contentOffset == CGPoint(x: -200, y: 0))

        // The outer scroll view has to be the one that moved.
        let placed = await host.settle { near(probe.frames["menu"]?.minX, 0) }
        #expect(placed, "outer child should be revealed, got \(String(describing: probe.frames["menu"]))")
    }

    // MARK: - Right to left

    @Test func rightToLeftPutsLeadingChildrenOnTheRight() async {
        let probe = Probe()
        let host = Host(menuStack(probe, direction: .rightToLeft))
        defer { host.close() }
        #expect(await mounted(probe, host))

        #expect(probe.engine.spec.items(at: .right).count == 1)
        #expect(probe.engine.spec.items(at: .left).isEmpty)

        #expect(await probe.proxy!.reveal("menu", animation: .immediate))
        #expect(probe.proxy!.contentOffset == CGPoint(x: 200, y: 0))

        let width = Bridge.container.width
        let placed = await host.settle { near(probe.frames["menu"]?.maxX, width) }
        #expect(placed, "revealed leading child sits at the right edge, got \(String(describing: probe.frames["menu"]))")
        #expect(near(probe.frames["root"]?.maxX, width - 200))
        #expect(probe.directions["menu"] == .rightToLeft, "content keeps the real direction")
        #expect(probe.directions["root"] == .rightToLeft)
    }
}

@Suite("Step callback", .timeLimit(.minutes(1)))
@MainActor
struct StepCallbackTests {

    @MainActor
    private final class Steps {
        var reported: [(StackItemID, StackNavigationStep)] = []
    }

    /// A drag released near a step decelerates onto it and reports it once settled.
    @Test func settlingAfterADragReportsTheStep() {
        let steps = Steps()
        let harness = Bridge.harness(extents: [200], steps: [[.init(0.5)]]) { configuration in
            configuration.onStep = { steps.reported.append(($0, $1)) }
        }

        var target = CGPoint(x: -90, y: 0)
        withUnsafeMutablePointer(to: &target) { pointer in
            harness.coordinator.scrollViewWillEndDragging(
                harness.scrollView, withVelocity: .zero, targetContentOffset: pointer
            )
        }
        harness.scrollView.contentOffset = target
        harness.coordinator.scrollViewDidEndDecelerating(harness.scrollView)

        #expect(steps.reported.count == 1)
        #expect(steps.reported.first?.0 == .position(.leading, 0))
        #expect(steps.reported.first?.1 == .init(0.5))
    }

    /// A drag that ends against the live range is clamped rather than
    /// paginated, and still reports the step it actually settled on.
    @Test func aClampedDragReportsTheStepItSettledOn() {
        let steps = Steps()
        let harness = Bridge.harness(extents: [200], steps: [[.init(0.5)]]) { configuration in
            configuration.onStep = { steps.reported.append(($0, $1)) }
        }
        harness.scrollView.contentOffset = CGPoint(x: -160, y: 0)
        harness.coordinator.scrollViewDidScroll(harness.scrollView)

        var target = CGPoint(x: -150, y: 0)
        withUnsafeMutablePointer(to: &target) { pointer in
            harness.coordinator.scrollViewWillEndDragging(
                harness.scrollView, withVelocity: CGPoint(x: -0.01, y: 0), targetContentOffset: pointer
            )
        }
        #expect(target == CGPoint(x: -100, y: 0))
        harness.scrollView.contentOffset = target
        harness.coordinator.scrollViewDidScroll(harness.scrollView)
        harness.coordinator.scrollViewDidEndDecelerating(harness.scrollView)

        #expect(steps.reported.map(\.1) == [.init(0.5)])
    }

    @Test func settlingBackAtTheRootReportsTheRoot() {
        let steps = Steps()
        let harness = Bridge.harness(extents: [200], steps: [[.init(0.5)]]) { configuration in
            configuration.onStep = { steps.reported.append(($0, $1)) }
        }

        var target = CGPoint(x: -20, y: 0)
        withUnsafeMutablePointer(to: &target) { pointer in
            harness.coordinator.scrollViewWillEndDragging(
                harness.scrollView, withVelocity: .zero, targetContentOffset: pointer
            )
        }
        harness.scrollView.contentOffset = target
        harness.coordinator.scrollViewDidEndDecelerating(harness.scrollView)

        #expect(steps.reported.first?.0 == .root)
    }
}
#endif
