import SwiftUI
import StackGeometry

public extension Animation {
    /// Makes the stack's curves reusable for ordinary SwiftUI state.
    ///
    /// The stack itself does not go through this: its curves drive a display
    /// link writing `UIScrollView.contentOffset`, which SwiftUI's animation
    /// system cannot own.
    static func stackEasing(_ easing: StackEasing, duration: TimeInterval = 0.25) -> Animation {
        Animation(StackEasingAnimation(easing: easing, duration: duration))
    }
}

private struct StackEasingAnimation: CustomAnimation {
    let easing: StackEasing
    let duration: TimeInterval

    func animate<V: VectorArithmetic>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? {
        guard time < duration else { return nil }
        return value.scaled(by: easing(time / duration))
    }

    func shouldMerge<V: VectorArithmetic>(
        previous: Animation, value: V, time: TimeInterval, context: inout AnimationContext<V>
    ) -> Bool {
        false
    }
}


extension StackEasingAnimation: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(duration)
    }
}
