import SCEdgeStack
import SwiftUI

/// Photo cards stacked on the top edge, each folding down flat in 3D as it is
/// uncovered.
struct GalleryDemo: View {
    @State private var curve = StackEasing.all.firstIndex { $0.name == "elasticOut" } ?? 0
    @State private var unfolded = -1

    var body: some View {
        StackReader { proxy in
            EdgeStack {
                GalleryRoot()
            } children: {
                ForEach(Photo.all) { photo in
                    PhotoCard(photo: photo)
                        .stackEdge(.top)
                        .stackID(photo.id)
                        .stackExtent(240)
                }
            }
            .stackLayout(FlapLayout(), for: .top)
            .stackAnimation(StackAnimation(curve: StackEasing.all[curve].easing, duration: 0.8))
            .onStackStep { id, step in
                let index = Photo.all.firstIndex { StackItemID($0.id) == id } ?? -1
                unfolded = step.fraction == 0 && index == 0 ? -1 : index
            }
            .overlay(alignment: .bottom) {
                controls(proxy)
            }
        }
    }

    private func controls(_ proxy: StackProxy) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("Curve").foregroundStyle(.secondary)
                Picker("Curve", selection: $curve) {
                    ForEach(StackEasing.all.indices, id: \.self) { index in
                        Text(StackEasing.all[index].name).tag(index)
                    }
                }
                .pickerStyle(.menu)
            }

            HStack(spacing: 10) {
                Button("Next", systemImage: "chevron.down") {
                    let next = min(unfolded + 1, Photo.all.count - 1)
                    Task { if await proxy.reveal(next) { unfolded = next } }
                }
                Button("All", systemImage: "chevron.down.2") {
                    Task {
                        for index in max(unfolded + 1, 0)..<Photo.all.count {
                            guard await proxy.reveal(index) else { return }
                            unfolded = index
                        }
                    }
                }
                Button("Fold", systemImage: "chevron.up") {
                    Task { if await proxy.fold() { unfolded = -1 } }
                }
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.regularMaterial, in: .rect(cornerRadius: 22, style: .continuous))
        .padding()
        .stackSafeArea(.bottom)
    }
}

/// Each card rotates about its horizontal axis from edge-on to flat, seen
/// from 500 points away.
struct FlapLayout: StackLayout {
    func effect(_ ctx: StackItemContext, finalFrame: CGRect, visibleFraction: Double) -> StackEffect {
        let vertical = ctx.axis == .vertical
        let extent = vertical ? finalFrame.height : finalFrame.width
        return StackEffect(
            rotation: StackRotation3D(
                radians: (1 - visibleFraction) * .pi / 2,
                axis: vertical ? (x: 1, y: 0, z: 0) : (x: 0, y: 1, z: 0),
                perspective: StackRotation3D.matchingM34(1 / -500, extent: extent)
            )
        )
    }
}

private struct GalleryRoot: View {
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.stack")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.orange.gradient)
            Text("Gallery").font(.largeTitle.bold())
            Text("Pull down to unfold the photos one at a time, or use the controls with any of the thirty easing curves.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 40)
            Image(systemName: "chevron.compact.down")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
                .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(colors: [Color(white: 0.14), .black], startPoint: .top, endPoint: .bottom)
        )
    }
}

/// Darkens while folded, and shows its caption once mostly flat.
private struct PhotoCard: View {
    @Environment(\.stackItem) private var item
    let photo: Photo

    var body: some View {
        let fraction = item?.visibleFraction ?? 0

        Artwork(colors: photo.colors, symbol: photo.symbol)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(photo.title).font(.title2.bold())
                    Text(photo.place).font(.subheadline)
                }
                .foregroundStyle(.white)
                .shadow(radius: 6)
                .padding()
                .opacity(clamp01((fraction - 0.6) / 0.4))
            }
            .clipShape(.rect(cornerRadius: 24, style: .continuous))
            .brightness(-0.5 * (1 - fraction))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
    }
}
