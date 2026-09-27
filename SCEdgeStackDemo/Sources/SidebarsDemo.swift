import SCEdgeStack
import SwiftUI

/// A mail client with a sidebar and an inspector on opposite edges. The
/// inbox shrinks into a card as either one opens.
struct SidebarsDemo: View {
    static let sidebarWidth: CGFloat = 280
    static let inspectorWidth: CGFloat = 300

    var body: some View {
        StackReader { proxy in
            EdgeStack {
                Inbox(
                    showSidebar: { Task { await proxy.reveal(Panel.sidebar) } },
                    showInspector: { Task { await proxy.reveal(Panel.inspector) } },
                    fold: { Task { await proxy.fold() } }
                )
            } children: {
                Sidebar()
                    .stackEdge(.leading)
                    .stackID(Panel.sidebar)
                    .stackExtent(Self.sidebarWidth)

                Inspector()
                    .stackEdge(.trailing)
                    .stackID(Panel.inspector)
                    .stackExtent(Self.inspectorWidth)
            }
            .stackLayout(ShrinkingRootLayout(width: Self.sidebarWidth), for: .leading)
            .stackLayout(ShrinkingRootLayout(width: Self.inspectorWidth), for: .trailing)
            .stackAnimation(StackAnimation(curve: .exponentialOut, duration: 0.5))
        }
        .background(Color(white: 0.06).ignoresSafeArea())
    }

    enum Panel: Hashable {
        case sidebar
        case inspector
    }
}

/// Parallax panels, and a root that shrinks towards the panel it makes room
/// for.
struct ShrinkingRootLayout: StackLayout {
    let width: CGFloat
    private let parallax = ParallaxStackLayout()

    func frame(_ ctx: StackItemContext, finalFrame: CGRect) -> CGRect {
        parallax.frame(ctx, finalFrame: finalFrame)
    }

    func rootEffect(_ ctx: StackRootContext, visibleFraction: Double) -> StackEffect {
        let progress = clamp01(abs(ctx.contentOffset.x) / width)
        let scale = 1 - 0.12 * progress
        return StackEffect(
            scale: CGSize(width: scale, height: scale),
            // Anchored on the side facing the panel, so the gap stays closed.
            scaleAnchor: CGPoint(x: ctx.contentOffset.x < 0 ? 0 : 1, y: 0.5)
        )
    }
}

// MARK: - Root

private struct Inbox: View {
    let showSidebar: () -> Void
    let showInspector: () -> Void
    let fold: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                Button(action: showSidebar) { Image(systemName: "sidebar.leading") }
                Text("Inbox").font(.title2.bold())
                Spacer()
                Button(action: showInspector) { Image(systemName: "info.circle") }
            }
            .font(.title3)
            .padding(.horizontal)
            // Clear of the demo's close button.
            .padding(.trailing, 52)
            .padding(.vertical, 12)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Message.all) { message in
                        MessageRow(message: message)
                        Divider().padding(.leading, 72)
                    }
                }
            }
        }
        .stackSafeArea()
        .background(Color(white: 0.12))
        .mask(RootCardShape())
        .overlay(FoldCatcher(fold: fold))
        .shadow(color: .black.opacity(0.5), radius: 24)
    }
}

/// Rounds the root's corners as it is covered. Only this shape re-renders per
/// tick; the inbox itself does not.
private struct RootCardShape: View {
    @Environment(\.stackRoot) private var root

    var body: some View {
        GeometryReader { geometry in
            let hidden = 1 - (root?.visibleFraction ?? 1)
            let progress = clamp01(hidden * geometry.size.width / SidebarsDemo.sidebarWidth)
            RoundedRectangle(cornerRadius: 44 * progress, style: .continuous)
        }
    }
}

/// While a panel is open, a tap anywhere on the root closes it.
private struct FoldCatcher: View {
    @Environment(\.stackRoot) private var root
    let fold: () -> Void

    var body: some View {
        if (root?.visibleFraction ?? 1) < 0.99 {
            Color.clear
                .contentShape(.rect)
                .onTapGesture(perform: fold)
        }
    }
}

private struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(message.initials)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(message.tint.gradient, in: .circle)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(message.sender).font(.headline)
                    Spacer()
                    Text(message.time).font(.caption).foregroundStyle(.secondary)
                }
                Text(message.subject).font(.subheadline)
                Text(message.preview)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
    }
}

// MARK: - Panels

/// Its rows slide in one after another, each driven by how much of the
/// sidebar is uncovered.
private struct Sidebar: View {
    @Environment(\.stackItem) private var item

    private let mailboxes: [(symbol: String, name: String, count: Int?)] = [
        ("tray.fill", "Inbox", 12),
        ("star.fill", "Starred", 3),
        ("paperplane.fill", "Sent", nil),
        ("doc.fill", "Drafts", 2),
        ("archivebox.fill", "Archive", nil),
        ("trash.fill", "Trash", nil),
    ]

    var body: some View {
        let fraction = item?.visibleFraction ?? 0

        VStack(alignment: .leading, spacing: 6) {
            Text("Mailboxes")
                .font(.largeTitle.bold())
                .padding(.bottom, 12)

            ForEach(Array(mailboxes.enumerated()), id: \.offset) { index, mailbox in
                // Later rows lag behind, so the list unfurls rather than slides.
                let lag = clamp01(fraction * 1.6 - Double(index) * 0.1)
                HStack(spacing: 14) {
                    Image(systemName: mailbox.symbol)
                        .foregroundStyle(.indigo)
                        .frame(width: 24)
                    Text(mailbox.name)
                    Spacer()
                    if let count = mailbox.count {
                        Text("\(count)").foregroundStyle(.secondary)
                    }
                }
                .font(.body.weight(.medium))
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(index == 0 ? AnyShapeStyle(.indigo.opacity(0.25)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 10))
                .opacity(lag)
                .offset(x: -(1 - lag) * 60)
            }

            Spacer()

            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill").font(.largeTitle)
                VStack(alignment: .leading) {
                    Text("Stefan").font(.headline)
                    Text("stefan@example.com").font(.caption).foregroundStyle(.secondary)
                }
            }
            .opacity(fraction)
        }
        .padding()
        .stackSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(white: 0.06))
    }
}

private struct Inspector: View {
    @State private var notify = true
    @State private var vip = false
    @State private var muted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Details").font(.largeTitle.bold())

            HStack(spacing: 14) {
                Text("AR")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(Color.pink.gradient, in: .circle)
                VStack(alignment: .leading) {
                    Text("Ada Rivers").font(.headline)
                    Text("ada@example.com").font(.subheadline).foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                Toggle("Notifications", isOn: $notify)
                Divider().padding(.vertical, 10)
                Toggle("VIP", isOn: $vip)
                Divider().padding(.vertical, 10)
                Toggle("Mute thread", isOn: $muted)
            }
            .padding()
            .background(Color(white: 0.14), in: .rect(cornerRadius: 14, style: .continuous))

            Spacer()
        }
        .padding()
        .padding(.top, 44)
        .stackSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(white: 0.06))
    }
}

private struct Message: Identifiable {
    let id: Int
    let sender: String
    let subject: String
    let preview: String
    let time: String
    let tint: Color

    var initials: String {
        sender.split(separator: " ").compactMap(\.first).map(String.init).joined()
    }

    static let all: [Message] = [
        Message(id: 0, sender: "Ada Rivers", subject: "Launch checklist", preview: "Everything's green on our side. Can you give the release notes one last pass before we ship?", time: "09:41", tint: .pink),
        Message(id: 1, sender: "Kai Moreno", subject: "Design review", preview: "Loved the new sidebar. One thought on the inspector spacing — attaching a mock.", time: "09:12", tint: .orange),
        Message(id: 2, sender: "Lena Park", subject: "Coffee?", preview: "Around the corner at 3? I want to hear how the rewrite is going.", time: "08:57", tint: .teal),
        Message(id: 3, sender: "Build Bot", subject: "All checks passed", preview: "main is green. 96 tests ran in 0.8 seconds.", time: "08:30", tint: .green),
        Message(id: 4, sender: "Omar Haddad", subject: "Trip photos", preview: "Finally uploaded the Dolomites album. The sunrise ones are unreal.", time: "Yesterday", tint: .blue),
        Message(id: 5, sender: "Mia Chen", subject: "Quarterly planning", preview: "Draft agenda is in the doc. Add anything you want covered by Friday.", time: "Yesterday", tint: .purple),
        Message(id: 6, sender: "Noah Weber", subject: "Re: API naming", preview: "Agreed — unfolding and folding read much better than forward and reverse.", time: "Tuesday", tint: .indigo),
        Message(id: 7, sender: "Sara Lind", subject: "Invoice #1042", preview: "Attached is the invoice for September. Let me know if anything looks off.", time: "Tuesday", tint: .mint),
        Message(id: 8, sender: "Theo Grant", subject: "Weekend hike", preview: "Weather looks perfect. Meeting at the trailhead at 7?", time: "Monday", tint: .brown),
        Message(id: 9, sender: "Ines Costa", subject: "Welcome aboard", preview: "So glad to have you on the team. Here's everything you need for your first week.", time: "Monday", tint: .red),
    ]
}
