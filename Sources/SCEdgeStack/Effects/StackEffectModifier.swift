#if os(iOS)
import SwiftUI
import StackGeometry

/// Applies a `StackEffect`.
///
/// `Equatable`, so the ticks where nothing moved cost nothing -- which is most
/// of them.
///
/// Order matters: the transform is `scale . rotate . translate`, so the
/// translation is expressed in unscaled model space and then scaled, matching
/// `CATransform3DTranslate(CATransform3DScale(...))`.
struct StackEffectModifier: ViewModifier, Equatable {
    let effect: StackEffect

    func body(content: Content) -> some View {
        content
            .transformEffect(effect.projection)
            .offset(x: effect.translation.width, y: effect.translation.height)
            .rotation3D(effect.rotation)
            .scaleEffect(
                effect.scale,
                anchor: UnitPoint(x: effect.scaleAnchor.x, y: effect.scaleAnchor.y)
            )
            .opacity(effect.opacity)
    }
}

private extension View {
    @ViewBuilder
    func rotation3D(_ rotation: StackRotation3D?) -> some View {
        if let rotation {
            rotation3DEffect(
                .radians(rotation.radians),
                axis: rotation.axis,
                anchorZ: rotation.anchorZ,
                perspective: rotation.perspective
            )
        } else {
            self
        }
    }
}
#endif
