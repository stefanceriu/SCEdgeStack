import CoreGraphics

/// A relative position within a stacked child at which scrolling should stop.
public struct StackNavigationStep: Hashable, Sendable, Comparable {
    /// A hard limit on travel past this step -- not a speed bump.
    ///
    /// A plain step already stops a drag and hands the rest to the next one.
    /// A block never releases: it is the floor or the ceiling.
    public enum Block: Hashable, Sendable {
        case none
        /// The child can never be revealed past this point by dragging.
        case unfolding
        /// The child can never be hidden past this point by dragging.
        case folding
    }

    /// Clamped to `0...1`.
    public let fraction: Double
    public let block: Block

    public init(_ fraction: Double, block: Block = .none) {
        self.fraction = min(max(fraction, 0), 1)
        self.block = block
    }

    public static let folded = StackNavigationStep(0)
    public static let full = StackNavigationStep(1)

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.fraction < rhs.fraction
    }

    /// The direction this step blocks travel in, if any.
    public var blockedTravel: StackTravel? {
        switch block {
        case .none: nil
        case .unfolding: .unfolding
        case .folding: .folding
        }
    }
}

/// Which directions of travel the stack constrains to navigation steps.
public struct StackNavigationConstraints: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let unfolding = StackNavigationConstraints(rawValue: 1 << 0)
    public static let folding = StackNavigationConstraints(rawValue: 1 << 1)
    public static let all: StackNavigationConstraints = [.unfolding, .folding]
}

public extension Array where Element == StackNavigationStep {
    /// The declared steps plus the implicit bound at the far end of `travel`,
    /// de-duplicated by fraction (declared steps win) and ordered along `travel`.
    ///
    /// Only the destination bound is implicit. The origin bound is never a
    /// stopping point for a journey that starts there.
    func candidates(towards travel: StackTravel) -> [StackNavigationStep] {
        let destination: StackNavigationStep = travel == .unfolding ? .full : .folded
        var byFraction: [Double: StackNavigationStep] = [destination.fraction: destination]
        for step in self {
            byFraction[step.fraction] = step
        }
        let sorted = byFraction.values.sorted()
        return travel == .unfolding ? sorted : sorted.reversed()
    }
}
