import SwiftUI

enum Demo: String, CaseIterable, Identifiable {
    case sheet
    case sidebars
    case gallery
    case lab

    var id: Self { self }

    var title: String {
        switch self {
        case .sheet: "Sheet"
        case .sidebars: "Sidebars"
        case .gallery: "Gallery"
        case .lab: "Lab"
        }
    }

    var subtitle: String {
        switch self {
        case .sheet: "Navigation steps as detents, a floor it never folds past, and a root that recedes."
        case .sidebars: "Two edges, parallax, a root that shrinks away and rows that follow their own visibility."
        case .gallery: "A stack of cards folding down in 3D, unfolded one by one with any easing curve."
        case .lab: "Every layout, edge and curve, with the offset, visibility and step callbacks live."
        }
    }

    var symbol: String {
        switch self {
        case .sheet: "rectangle.bottomhalf.inset.filled"
        case .sidebars: "sidebar.squares.leading"
        case .gallery: "photo.stack"
        case .lab: "slider.horizontal.3"
        }
    }

    var tint: Color {
        switch self {
        case .sheet: .blue
        case .sidebars: .indigo
        case .gallery: .orange
        case .lab: .mint
        }
    }

    @MainActor @ViewBuilder
    var view: some View {
        switch self {
        case .sheet: SheetDemo()
        case .sidebars: SidebarsDemo()
        case .gallery: GalleryDemo()
        case .lab: LabDemo()
        }
    }
}

struct ContentView: View {
    @State private var presented: Demo?

    var body: some View {
        NavigationStack {
            List(Demo.allCases) { demo in
                Button { presented = demo } label: {
                    HStack(spacing: 16) {
                        Image(systemName: demo.symbol)
                            .font(.title2)
                            .foregroundStyle(demo.tint)
                            .frame(width: 48, height: 48)
                            .background(demo.tint.opacity(0.18), in: .rect(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(demo.title).font(.headline)
                            Text(demo.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("SCEdgeStack")
        }
        // Full screen rather than pushed: a navigation stack's back swipe would
        // fight every stack with a leading edge.
        .fullScreenCover(item: $presented) { demo in
            demo.view
                .overlay(alignment: .topTrailing) {
                    CloseButton { presented = nil }
                }
        }
    }
}
