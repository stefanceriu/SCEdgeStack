import SwiftUI

func clamp01(_ value: Double) -> Double {
    min(max(value, 0), 1)
}

struct CloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.headline)
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial, in: .circle)
        }
        .foregroundStyle(.primary)
        .padding()
        .accessibilityLabel("Close")
    }
}

/// Generated artwork, so the demos need no image assets.
struct Artwork: View {
    let colors: [Color]
    var symbol: String?

    var body: some View {
        MeshGradient(
            width: 3,
            height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.65, 0.4], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: colors
        )
        .overlay {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 64, weight: .light))
                    .foregroundStyle(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 12)
            }
        }
    }
}

struct Photo: Identifiable {
    let id: Int
    let title: String
    let place: String
    let symbol: String
    let colors: [Color]

    static let all: [Photo] = [
        Photo(id: 0, title: "Aurora", place: "Tromsø, Norway", symbol: "sparkles", colors: [
            .black, .indigo, .black,
            .teal, .green, .purple,
            .black, .indigo, .black,
        ]),
        Photo(id: 1, title: "Dunes", place: "Erg Chebbi, Morocco", symbol: "sun.horizon.fill", colors: [
            .orange, .yellow, .orange,
            .red, .orange, .yellow,
            .brown, .red, .orange,
        ]),
        Photo(id: 2, title: "Lagoon", place: "Bora Bora", symbol: "water.waves", colors: [
            .cyan, .teal, .blue,
            .mint, .cyan, .teal,
            .blue, .teal, .cyan,
        ]),
        Photo(id: 3, title: "Summit", place: "Dolomites, Italy", symbol: "mountain.2.fill", colors: [
            .blue, .indigo, .blue,
            .gray, .white, .gray,
            .green, .gray, .green,
        ]),
        Photo(id: 4, title: "Night sky", place: "Atacama, Chile", symbol: "moon.stars.fill", colors: [
            .black, .purple, .black,
            .indigo, .black, .purple,
            .black, .indigo, .black,
        ]),
    ]
}
