import SCEdgeStack
import SwiftUI

/// Every built-in layout on any edge, with any curve, and the callbacks shown
/// live. The stack sits in a card: it is just a view.
struct LabDemo: View {
    @State private var layout = LayoutChoice.parallax
    @State private var edge = StackEdge.leading
    @State private var curve = StackEasing.all.firstIndex { $0.name == "backOut" } ?? 0
    @State private var duration = 0.6
    @State private var paging = true
    @State private var halfSteps = false
    @State private var rightToLeft = false
    @State private var events: [String] = []

    private static let panels = 3

    var body: some View {
        StackReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                Text("Lab")
                    .font(.largeTitle.bold())
                    .padding(.horizontal)
                    .padding(.top, 8)

                preview
                    .frame(height: 300)
                    .clipShape(.rect(cornerRadius: 24, style: .continuous))
                    .padding()

                Telemetry(proxy: proxy, events: events)
                    .padding(.horizontal)

                controls(proxy)
            }
        }
    }

    private var preview: some View {
        EdgeStack {
            LabRoot(edge: edge)
        } children: {
            ForEach(0..<Self.panels, id: \.self) { index in
                LabPanel(index: index)
                    .stackEdge(edge)
                    .stackID(index)
                    .stackExtent(84)
                    .stackNavigationSteps(halfSteps ? [.init(0.5)] : [])
            }
        }
        .stackLayout(layout.layout, for: edge)
        .stackPagingEnabled(paging)
        .stackAnimation(StackAnimation(curve: StackEasing.all[curve].easing, duration: duration))
        .onStackVisibilityChange { id, visible in
            log("\(name(id)) \(visible ? "appeared" : "disappeared")")
        }
        .onStackStep { id, step in
            log("Settled on \(name(id)) at \(step.fraction.formatted(.percent))")
        }
        .environment(\.layoutDirection, rightToLeft ? .rightToLeft : .leftToRight)
    }

    private func name(_ id: StackItemID) -> String {
        (0..<Self.panels).first { StackItemID($0) == id }.map { "Panel \($0 + 1)" } ?? "Root"
    }

    private func controls(_ proxy: StackProxy) -> some View {
        Form {
            Section("Navigate") {
                HStack {
                    ForEach(0..<Self.panels, id: \.self) { index in
                        Button("\(index + 1)") { Task { await proxy.reveal(index) } }
                    }
                    Spacer()
                    Button("Fold") { Task { await proxy.fold() } }
                }
                .buttonStyle(.bordered)
            }

            Section("Layout") {
                Picker("Layout", selection: $layout) {
                    ForEach(LayoutChoice.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("Edge", selection: $edge) {
                    ForEach(StackEdge.allCases, id: \.self) { Text(String(describing: $0).capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle("Right to left", isOn: $rightToLeft)
            }

            Section("Animation") {
                Picker("Curve", selection: $curve) {
                    ForEach(StackEasing.all.indices, id: \.self) { Text(StackEasing.all[$0].name).tag($0) }
                }
                LabeledContent("Duration") {
                    HStack {
                        Slider(value: $duration, in: 0.1...2)
                        Text(duration.formatted(.number.precision(.fractionLength(1))) + " s")
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                }
            }

            Section("Paging") {
                Toggle("Snap to steps", isOn: $paging)
                Toggle("Half-way steps", isOn: $halfSteps)
            }
        }
    }

    private func log(_ event: String) {
        events.insert(event, at: 0)
        events = Array(events.prefix(3))
    }
}

enum LayoutChoice: String, CaseIterable, Identifiable {
    case plain = "Plain"
    case sliding = "Sliding"
    case parallax = "Parallax"
    case reversed = "Reversed"
    case resizing = "Resizing"

    var id: Self { self }

    var layout: any StackLayout {
        switch self {
        case .plain: PlainStackLayout()
        case .sliding: SlidingStackLayout()
        case .parallax: ParallaxStackLayout()
        case .reversed: ReversedStackLayout()
        case .resizing: ResizingStackLayout()
        }
    }
}

/// Reads `contentOffset` straight off the proxy. Only this view re-renders on
/// every tick.
private struct Telemetry: View {
    let proxy: StackProxy
    let events: [String]

    var body: some View {
        let offset = proxy.contentOffset
        VStack(alignment: .leading, spacing: 4) {
            Text("offset  x \(Int(offset.x))  y \(Int(offset.y))")
                .font(.system(.footnote, design: .monospaced))
            ForEach(Array(events.enumerated()), id: \.offset) { index, event in
                Text(event)
                    .font(.caption)
                    .foregroundStyle(index == 0 ? .primary : .secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
    }
}

private struct LabRoot: View {
    let edge: StackEdge

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: arrow).font(.largeTitle)
            Text("Drag from the \(String(describing: edge)) edge")
                .font(.headline)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LinearGradient(colors: [.mint, .teal], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private var arrow: String {
        switch edge {
        case .top: "arrow.down"
        case .leading: "arrow.forward"
        case .bottom: "arrow.up"
        case .trailing: "arrow.backward"
        }
    }
}

/// Shows its own visible fraction, read through the pull API.
private struct LabPanel: View {
    @Environment(\.stackItem) private var item
    let index: Int

    private static let tints: [Color] = [.indigo, .pink, .orange]

    var body: some View {
        let fraction = item?.visibleFraction ?? 0
        VStack(spacing: 6) {
            Text("\(index + 1)").font(.title.bold())
            Text(fraction.formatted(.percent.precision(.fractionLength(0))))
                .font(.system(.caption, design: .monospaced))
            Gauge(value: fraction) {}
                .gaugeStyle(.accessoryLinearCapacity)
                .tint(.white)
                .frame(width: 56)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Self.tints[index].gradient)
    }
}
