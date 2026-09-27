import CoreGraphics
import QuartzCore
import Testing
@testable import StackGeometry

@Suite("Effect composition")
struct EffectTests {

    /// The documented composition, matching the order the item host applies its
    /// modifiers in: `scale . rotate . translate`.
    private func matrix(_ effect: StackEffect) -> CATransform3D {
        var transform = CATransform3DIdentity
        transform = CATransform3DScale(transform, effect.scale.width, effect.scale.height, 1)
        if let rotation = effect.rotation {
            transform = CATransform3DRotate(
                transform, rotation.radians, rotation.axis.x, rotation.axis.y, rotation.axis.z
            )
        }
        return CATransform3DTranslate(transform, effect.translation.width, effect.translation.height, 0)
    }

    private func expectEqual(_ lhs: CATransform3D, _ rhs: CATransform3D, _ note: Comment? = nil) {
        let l = [lhs.m11, lhs.m12, lhs.m21, lhs.m22, lhs.m41, lhs.m42]
        let r = [rhs.m11, rhs.m12, rhs.m21, rhs.m22, rhs.m41, rhs.m42]
        for (a, b) in zip(l, r) {
            #expect(abs(a - b) < 1e-9, note ?? "")
        }
    }

    /// `CATransform3DTranslate(CATransform3DScale(...))` translates in scaled
    /// space. This pins that `StackEffect.translation` does the same.
    @Test func translationIsPreScale() {
        let effect = StackEffect(
            scale: CGSize(width: 0.5, height: 0.5),
            translation: CGSize(width: 100, height: 0)
        )
        let reference = CATransform3DTranslate(
            CATransform3DScale(CATransform3DIdentity, 0.5, 0.5, 1), 100, 0, 0
        )
        expectEqual(matrix(effect), reference)

        // The visible displacement is the scaled translation, not the raw one.
        #expect(abs(CATransform3DGetAffineTransform(reference).tx - 50) < 1e-9)
    }

    @Test func rotationSitsBetweenScaleAndTranslation() {
        let effect = StackEffect(
            scale: CGSize(width: 2, height: 2),
            translation: CGSize(width: 10, height: 0),
            rotation: StackRotation3D(radians: .pi / 2, axis: (0, 0, 1))
        )
        let reference = CATransform3DTranslate(
            CATransform3DRotate(
                CATransform3DScale(CATransform3DIdentity, 2, 2, 1), .pi / 2, 0, 0, 1
            ),
            10, 0, 0
        )
        expectEqual(matrix(effect), reference)
    }

    /// An effect that wants the translation *after* the rotation -- which the
    /// fixed order cannot express -- is recovered by pre-rotating it.
    @Test func aPostRotationTranslationIsRecoveredByPreRotatingIt() {
        let angle = Double.pi / 2
        let wanted = CATransform3DRotate(
            CATransform3DTranslate(CATransform3DIdentity, 400, 400, 0), angle, 0, 0, 1
        )

        let pre = CGPoint(x: 400, y: 400).applying(CGAffineTransform(rotationAngle: -angle))
        let effect = StackEffect(
            translation: CGSize(width: pre.x, height: pre.y),
            rotation: StackRotation3D(radians: angle, axis: (0, 0, 1))
        )
        expectEqual(matrix(effect), wanted)
    }

    /// Core Animation's `m34` is absolute; SwiftUI's `perspective` is relative
    /// to the view's extent.
    @Test func matchingM34ConvertsAbsolutePerspectiveToRelative() {
        #expect(abs(StackRotation3D.matchingM34(1 / -500, extent: 375) - 0.75) < 1e-9)
        #expect(abs(StackRotation3D.matchingM34(1 / -500, extent: 1000) - 2) < 1e-9)
        #expect(StackRotation3D.matchingM34(0, extent: 375) == 0)
    }

    @Test func identityIsIdentity() {
        expectEqual(matrix(.identity), CATransform3DIdentity)
        #expect(StackEffect.identity.isIdentity)
    }

    /// Equality is what lets an unchanged effect skip its modifier update, so
    /// every rotation field has to take part in it.
    @Test func rotationEqualityComparesEveryField() {
        let base = StackRotation3D(radians: 1, axis: (1, 0, 0), anchorZ: 0, perspective: 1)
        #expect(base == StackRotation3D(radians: 1, axis: (1, 0, 0), anchorZ: 0, perspective: 1))
        #expect(base != StackRotation3D(radians: 2, axis: (1, 0, 0), anchorZ: 0, perspective: 1))
        #expect(base != StackRotation3D(radians: 1, axis: (0, 1, 0), anchorZ: 0, perspective: 1))
        #expect(base != StackRotation3D(radians: 1, axis: (1, 0, 0), anchorZ: 5, perspective: 1))
        #expect(base != StackRotation3D(radians: 1, axis: (1, 0, 0), anchorZ: 0, perspective: 2))
    }

    @Test func anyChangedFieldIsNotIdentity() {
        #expect(!StackEffect(opacity: 0.5).isIdentity)
        #expect(!StackEffect(zIndex: 1).isIdentity)
        #expect(!StackEffect(scaleAnchor: .zero).isIdentity)
        #expect(!StackEffect(projection: CGAffineTransform(scaleX: 2, y: 2)).isIdentity)
        #expect(!StackEffect(rotation: StackRotation3D(radians: 0, axis: (0, 0, 1))).isIdentity)
    }
}
