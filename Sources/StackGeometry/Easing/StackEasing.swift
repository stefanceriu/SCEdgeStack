import Foundation

/// A normalised easing curve, `f(0) == 0`, `f(1) == 1`.
///
/// A value type wrapping a function rather than thirty `CustomAnimation`
/// conformances: these curves drive a `CADisplayLink` writing
/// `UIScrollView.contentOffset`, which SwiftUI's animation system cannot own.
///
/// Functions cannot be compared, so a curve is equal only to itself: copies of
/// one value are equal, two values wrapping the same function are not.
public struct StackEasing: Sendable, Hashable {
    public let solve: @Sendable (Double) -> Double
    private let identity = UUID()

    public init(_ solve: @escaping @Sendable (Double) -> Double) {
        self.solve = solve
    }

    public func callAsFunction(_ p: Double) -> Double { solve(p) }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.identity == rhs.identity }
    public func hash(into hasher: inout Hasher) { hasher.combine(identity) }
}

// Ported from easing.c, (c) 2011 Auerhaus Development, LLC, released under the
// WTFPL. See NOTICE.
public extension StackEasing {

    static let linear = StackEasing { $0 }

    static let quadraticIn = StackEasing { $0 * $0 }
    static let quadraticOut = StackEasing { -($0 * ($0 - 2)) }
    static let quadraticInOut = StackEasing { p in
        p < 0.5 ? 2 * p * p : (-2 * p * p) + (4 * p) - 1
    }

    static let cubicIn = StackEasing { $0 * $0 * $0 }
    static let cubicOut = StackEasing { p in
        let f = p - 1
        return f * f * f + 1
    }
    static let cubicInOut = StackEasing { p in
        if p < 0.5 { return 4 * p * p * p }
        let f = (2 * p) - 2
        return 0.5 * f * f * f + 1
    }

    static let quarticIn = StackEasing { $0 * $0 * $0 * $0 }
    static let quarticOut = StackEasing { p in
        let f = p - 1
        return f * f * f * (1 - p) + 1
    }
    static let quarticInOut = StackEasing { p in
        if p < 0.5 { return 8 * p * p * p * p }
        let f = p - 1
        return -8 * f * f * f * f + 1
    }

    static let quinticIn = StackEasing { $0 * $0 * $0 * $0 * $0 }
    static let quinticOut = StackEasing { p in
        let f = p - 1
        return f * f * f * f * f + 1
    }
    static let quinticInOut = StackEasing { p in
        if p < 0.5 { return 16 * p * p * p * p * p }
        let f = (2 * p) - 2
        return 0.5 * f * f * f * f * f + 1
    }

    static let sineIn = StackEasing { sin(($0 - 1) * .pi / 2) + 1 }
    static let sineOut = StackEasing { sin($0 * .pi / 2) }
    static let sineInOut = StackEasing { 0.5 * (1 - cos($0 * .pi)) }

    static let circularIn = StackEasing { 1 - (1 - ($0 * $0)).squareRoot() }
    static let circularOut = StackEasing { ((2 - $0) * $0).squareRoot() }
    static let circularInOut = StackEasing { p in
        p < 0.5
            ? 0.5 * (1 - (1 - 4 * (p * p)).squareRoot())
            : 0.5 * ((-((2 * p) - 3) * ((2 * p) - 1)).squareRoot() + 1)
    }

    static let exponentialIn = StackEasing { $0 == 0 ? $0 : pow(2, 10 * ($0 - 1)) }
    static let exponentialOut = StackEasing { $0 == 1 ? $0 : 1 - pow(2, -10 * $0) }
    static let exponentialInOut = StackEasing { p in
        if p == 0 || p == 1 { return p }
        return p < 0.5 ? 0.5 * pow(2, (20 * p) - 10) : -0.5 * pow(2, (-20 * p) + 10) + 1
    }

    static let elasticIn = StackEasing { sin(13 * .pi / 2 * $0) * pow(2, 10 * ($0 - 1)) }
    static let elasticOut = StackEasing { sin(-13 * .pi / 2 * ($0 + 1)) * pow(2, -10 * $0) + 1 }
    static let elasticInOut = StackEasing { p in
        p < 0.5
            ? 0.5 * sin(13 * .pi / 2 * (2 * p)) * pow(2, 10 * ((2 * p) - 1))
            : 0.5 * (sin(-13 * .pi / 2 * ((2 * p - 1) + 1)) * pow(2, -10 * (2 * p - 1)) + 2)
    }

    static let backIn = StackEasing { $0 * $0 * $0 - $0 * sin($0 * .pi) }
    static let backOut = StackEasing { p in
        let f = 1 - p
        return 1 - (f * f * f - f * sin(f * .pi))
    }
    static let backInOut = StackEasing { p in
        if p < 0.5 {
            let f = 2 * p
            return 0.5 * (f * f * f - f * sin(f * .pi))
        }
        let f = 1 - (2 * p - 1)
        return 0.5 * (1 - (f * f * f - f * sin(f * .pi))) + 0.5
    }

    static let bounceIn = StackEasing { 1 - bounceOut(1 - $0) }
    static let bounceOut = StackEasing { p in
        if p < 4 / 11.0 { return (121 * p * p) / 16.0 }
        if p < 8 / 11.0 { return (363 / 40.0 * p * p) - (99 / 10.0 * p) + 17 / 5.0 }
        if p < 9 / 10.0 { return (4356 / 361.0 * p * p) - (35442 / 1805.0 * p) + 16061 / 1805.0 }
        return (54 / 5.0 * p * p) - (513 / 25.0 * p) + 268 / 25.0
    }
    static let bounceInOut = StackEasing { p in
        p < 0.5 ? 0.5 * bounceIn(p * 2) : 0.5 * bounceOut(p * 2 - 1) + 0.5
    }

    /// Every shipped curve, in declaration order.
    static let all: [(name: String, easing: StackEasing)] = [
        ("linear", .linear),
        ("quadraticIn", .quadraticIn), ("quadraticOut", .quadraticOut), ("quadraticInOut", .quadraticInOut),
        ("cubicIn", .cubicIn), ("cubicOut", .cubicOut), ("cubicInOut", .cubicInOut),
        ("quarticIn", .quarticIn), ("quarticOut", .quarticOut), ("quarticInOut", .quarticInOut),
        ("quinticIn", .quinticIn), ("quinticOut", .quinticOut), ("quinticInOut", .quinticInOut),
        ("sineIn", .sineIn), ("sineOut", .sineOut), ("sineInOut", .sineInOut),
        ("circularIn", .circularIn), ("circularOut", .circularOut), ("circularInOut", .circularInOut),
        ("exponentialIn", .exponentialIn), ("exponentialOut", .exponentialOut), ("exponentialInOut", .exponentialInOut),
        ("elasticIn", .elasticIn), ("elasticOut", .elasticOut), ("elasticInOut", .elasticInOut),
        ("backIn", .backIn), ("backOut", .backOut), ("backInOut", .backInOut),
        ("bounceIn", .bounceIn), ("bounceOut", .bounceOut), ("bounceInOut", .bounceInOut)
    ]
}
