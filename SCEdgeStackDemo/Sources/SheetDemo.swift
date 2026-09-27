import SCEdgeStack
import SwiftUI

/// A Maps-style sheet. Its detents are navigation steps: one swipe advances one
/// detent, and a folding block keeps it from ever folding away completely.
struct SheetDemo: View {
    @State private var detent = Detent.peek

    enum Detent: String, CaseIterable, Identifiable {
        case peek = "Peek"
        case half = "Half"
        case full = "Full"

        var id: Self { self }

        var step: StackNavigationStep {
            switch self {
            case .peek: .init(0.16, block: .folding)
            case .half: .init(0.5)
            case .full: .full
            }
        }

        init(_ step: StackNavigationStep) {
            self = step.fraction < 0.3 ? .peek : step.fraction < 0.75 ? .half : .full
        }
    }

    static let sheet = "sheet"

    var body: some View {
        GeometryReader { geometry in
            StackReader { proxy in
                EdgeStack {
                    MapRoot(detent: detent) { target in
                        Task { await proxy.reveal(Self.sheet, to: target.step) }
                    }
                } children: {
                    PlaceSheet()
                        .stackEdge(.bottom)
                        .stackID(Self.sheet)
                        .stackExtent(geometry.size.height * 0.9)
                        .stackNavigationSteps([Detent.peek.step, Detent.half.step])
                }
                .stackLayout(SheetLayout(), for: .bottom)
                .stackAnimation(StackAnimation(curve: .quinticOut, duration: 0.45))
                .onStackStep { _, step in detent = Detent(step) }
                .task {
                    // Measurement lands a turn after the first layout; retry until
                    // the sheet is addressable, then settle it on its floor.
                    for _ in 0..<60 {
                        if await proxy.reveal(Self.sheet, to: Detent.peek.step, animation: .immediate) { break }
                        try? await Task.sleep(for: .milliseconds(16))
                    }
                }
            }
        }
    }
}

/// The sheet slides over a root that stays put, and the root recedes once the
/// sheet passes half way.
struct SheetLayout: StackLayout {
    var stacksAboveRoot: Bool { true }

    func rootEffect(_ ctx: StackRootContext, visibleFraction: Double) -> StackEffect {
        let covered = ctx.contentOffset.y / ctx.containerSize.height
        let recede = clamp01((covered - 0.45) / 0.45)
        let scale = 1 - 0.07 * recede
        return StackEffect(scale: CGSize(width: scale, height: scale))
    }
}

private struct MapRoot: View {
    let detent: SheetDemo.Detent
    let select: (SheetDemo.Detent) -> Void

    var body: some View {
        ZStack {
            Artwork(colors: [
                Color(red: 0.55, green: 0.75, blue: 0.95), Color(red: 0.6, green: 0.8, blue: 0.95), Color(red: 0.75, green: 0.85, blue: 0.7),
                Color(red: 0.7, green: 0.85, blue: 0.65), Color(red: 0.85, green: 0.88, blue: 0.75), Color(red: 0.7, green: 0.82, blue: 0.6),
                Color(red: 0.8, green: 0.86, blue: 0.7), Color(red: 0.65, green: 0.8, blue: 0.6), Color(red: 0.55, green: 0.75, blue: 0.95),
            ])

            GeometryReader { geometry in
                let size = geometry.size
                Roads(size: size)
                ForEach(Place.all) { place in
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, place.tint)
                        .shadow(radius: 4)
                        .position(x: place.pin.x * size.width, y: place.pin.y * size.height)
                }

                Circle()
                    .fill(.blue)
                    .stroke(.white, lineWidth: 3)
                    .frame(width: 18, height: 18)
                    .shadow(color: .blue, radius: 8)
                    .position(x: 0.5 * size.width, y: 0.38 * size.height)
            }

            RootDimming()
        }
        .mask(RecedingCorners())
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(SheetDemo.Detent.allCases) { option in
                        Button(option.rawValue) { select(option) }
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(option == detent ? AnyShapeStyle(.blue) : AnyShapeStyle(.clear), in: .capsule)
                            .foregroundStyle(option == detent ? .white : .primary)
                    }
                }
                Text("Reported by onStackStep")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.regularMaterial, in: .rect(cornerRadius: 14, style: .continuous))
            .padding()
            .stackSafeArea()
        }
    }
}

private struct Roads: View {
    let size: CGSize

    var body: some View {
        let w = size.width, h = size.height
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0.62 * h))
            path.addCurve(to: CGPoint(x: w, y: 0.3 * h), control1: CGPoint(x: 0.35 * w, y: 0.55 * h), control2: CGPoint(x: 0.6 * w, y: 0.2 * h))
            path.move(to: CGPoint(x: 0.42 * w, y: 0))
            path.addCurve(to: CGPoint(x: 0.55 * w, y: h), control1: CGPoint(x: 0.3 * w, y: 0.4 * h), control2: CGPoint(x: 0.7 * w, y: 0.6 * h))
            path.move(to: CGPoint(x: 0, y: 0.2 * h))
            path.addLine(to: CGPoint(x: w, y: 0.45 * h))
            path.move(to: CGPoint(x: 0.1 * w, y: h))
            path.addQuadCurve(to: CGPoint(x: w, y: 0.75 * h), control: CGPoint(x: 0.5 * w, y: 0.7 * h))
        }
        .stroke(.white.opacity(0.85), style: StrokeStyle(lineWidth: 7, lineCap: .round))
        .shadow(color: .black.opacity(0.08), radius: 2)
    }
}

/// Rounds the map's corners as it recedes behind the sheet.
private struct RecedingCorners: View {
    @Environment(\.stackRoot) private var root

    var body: some View {
        let covered = 1 - (root?.visibleFraction ?? 1)
        RoundedRectangle(cornerRadius: 40 * clamp01((covered - 0.45) / 0.45), style: .continuous)
    }
}

/// Reads the root's visible fraction through the pull API. Only this view
/// re-renders as the sheet moves.
private struct RootDimming: View {
    @Environment(\.stackRoot) private var root

    var body: some View {
        let covered = 1 - (root?.visibleFraction ?? 1)
        Color.black
            .opacity(0.5 * clamp01((covered - 0.45) / 0.45))
            .allowsHitTesting(false)
    }
}

private struct PlaceSheet: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Capsule()
                .fill(.secondary)
                .frame(width: 36, height: 5)
                .frame(maxWidth: .infinity)

            HStack {
                Image(systemName: "magnifyingglass")
                Text("Search places")
                Spacer()
                Image(systemName: "mic.fill")
            }
            .foregroundStyle(.secondary)
            .padding(12)
            .background(.fill.tertiary, in: .rect(cornerRadius: 12, style: .continuous))

            SheetDetails()
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(alignment: .top) {
            // Extends below the sheet, so rubber-banding past full shows more
            // sheet instead of a gap.
            UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                .fill(Color(white: 0.11))
                .padding(.bottom, -400)
                .shadow(color: .black.opacity(0.35), radius: 20)
        }
    }
}

/// Fades in as the sheet is uncovered past its peek.
private struct SheetDetails: View {
    @Environment(\.stackItem) private var item

    var body: some View {
        let reveal = clamp01(((item?.visibleFraction ?? 0) - 0.18) / 0.25)

        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(["Coffee", "Parks", "Museums", "Food", "Views"], id: \.self) { chip in
                        Text(chip)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.fill.secondary, in: .capsule)
                    }
                }
            }

            Text("Nearby").font(.title3.bold())

            ForEach(Place.all) { place in
                HStack(spacing: 14) {
                    Image(systemName: place.symbol)
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(place.tint.gradient, in: .circle)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(place.name).font(.headline)
                        Text(place.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(place.distance).font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .opacity(reveal)
        .offset(y: (1 - reveal) * 24)
    }
}

private struct Place: Identifiable {
    let id: Int
    let name: String
    let detail: String
    let distance: String
    let symbol: String
    let tint: Color
    /// Unit coordinates on the map.
    let pin: CGPoint

    static let all: [Place] = [
        Place(id: 0, name: "Harbour Coffee", detail: "Café · Open until 18:00", distance: "250 m", symbol: "cup.and.saucer.fill", tint: .brown, pin: CGPoint(x: 0.3, y: 0.28)),
        Place(id: 1, name: "Botanic Garden", detail: "Park · Free entry", distance: "900 m", symbol: "leaf.fill", tint: .green, pin: CGPoint(x: 0.74, y: 0.22)),
        Place(id: 2, name: "Modern Art Museum", detail: "Museum · Closes 20:00", distance: "1.4 km", symbol: "building.columns.fill", tint: .purple, pin: CGPoint(x: 0.2, y: 0.5)),
        Place(id: 3, name: "Night Market", detail: "Food · Busy now", distance: "2.1 km", symbol: "fork.knife", tint: .orange, pin: CGPoint(x: 0.78, y: 0.55)),
        Place(id: 4, name: "Lookout Point", detail: "Viewpoint · Best at sunset", distance: "3.0 km", symbol: "binoculars.fill", tint: .blue, pin: CGPoint(x: 0.56, y: 0.14)),
    ]
}
