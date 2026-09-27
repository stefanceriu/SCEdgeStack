import Foundation
import StackGeometry

/// A curve and a duration, used for programmatic navigation.
public struct StackAnimation: Sendable {
    public var curve: StackEasing
    public var duration: TimeInterval

    public init(curve: StackEasing = .sineInOut, duration: TimeInterval = 0.25) {
        self.curve = curve
        self.duration = duration
    }

    /// Jumps straight to the target.
    public static let immediate = StackAnimation(curve: .linear, duration: 0)
}
