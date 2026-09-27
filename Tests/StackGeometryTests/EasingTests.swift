import Foundation
import Testing
@testable import StackGeometry

@Suite("Easing curves")
struct EasingTests {

    static let curves = StackEasing.all

    @Test(arguments: curves)
    func pinnedAtBothEnds(entry: (name: String, easing: StackEasing)) {
        #expect(abs(entry.easing(0)) < 1e-9, "\(entry.name) f(0)")
        #expect(abs(entry.easing(1) - 1) < 1e-9, "\(entry.name) f(1)")
    }

    @Test(arguments: curves)
    func finiteOverTheWholeDomain(entry: (name: String, easing: StackEasing)) {
        for sample in 0...1000 {
            let value = entry.easing(Double(sample) / 1000)
            #expect(value.isFinite, "\(entry.name) at \(sample)")
        }
    }

    /// The `InOut` variants are point-symmetric about `(0.5, 0.5)` wherever the
    /// underlying curve is. Elastic and back overshoot asymmetrically by design.
    @Test(arguments: curves.filter {
        $0.name.hasSuffix("InOut") && !["elasticInOut", "backInOut", "bounceInOut"].contains($0.name)
    })
    func inOutVariantsArePointSymmetric(entry: (name: String, easing: StackEasing)) {
        for sample in 0...500 {
            let p = Double(sample) / 1000
            let lhs = entry.easing(p)
            let rhs = 1 - entry.easing(1 - p)
            #expect(abs(lhs - rhs) < 1e-6, "\(entry.name) at \(p): \(lhs) vs \(rhs)")
        }
    }

    @Test(arguments: curves.filter { !["elasticIn", "elasticOut", "elasticInOut",
                                       "backIn", "backOut", "backInOut"].contains($0.name) })
    func nonOvershootingCurvesStayInRange(entry: (name: String, easing: StackEasing)) {
        for sample in 0...1000 {
            let value = entry.easing(Double(sample) / 1000)
            #expect(value >= -1e-9 && value <= 1 + 1e-9, "\(entry.name) at \(sample): \(value)")
        }
    }

    /// Elastic and back are allowed to overshoot, but not without bound --
    /// a curve that runs away would throw the scroll offset off screen.
    @Test(arguments: curves.filter { $0.name.hasPrefix("elastic") || $0.name.hasPrefix("back") })
    func overshootIsBounded(entry: (name: String, easing: StackEasing)) {
        for sample in 0...1000 {
            let value = entry.easing(Double(sample) / 1000)
            #expect(value > -0.5 && value < 1.5, "\(entry.name) at \(sample): \(value)")
        }
    }

    @Test func thirtyCurvesShipped() {
        #expect(StackEasing.all.count == 31, "thirty curves plus linear")
        #expect(Set(StackEasing.all.map(\.name)).count == StackEasing.all.count)
    }

    /// Functions cannot be compared, so a curve is equal only to itself.
    @Test func curvesAreEqualOnlyToThemselves() {
        let copy = StackEasing.sineInOut
        #expect(copy == .sineInOut)
        #expect(StackEasing.sineInOut != .linear)
        #expect(StackEasing { $0 } != StackEasing { $0 })
    }
}
