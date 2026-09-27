import CoreGraphics

/// A 3D rotation, expressed the way SwiftUI's `rotation3DEffect` wants it.
public struct StackRotation3D: Equatable, Sendable {
    public var radians: Double
    public var axis: (x: CGFloat, y: CGFloat, z: CGFloat)
    public var anchorZ: CGFloat
    /// SwiftUI's perspective is relative to the view's extent; Core Animation's
    /// `m34` is absolute. See `matchingM34(_:extent:)`.
    public var perspective: CGFloat

    public init(
        radians: Double,
        axis: (x: CGFloat, y: CGFloat, z: CGFloat),
        anchorZ: CGFloat = 0,
        perspective: CGFloat = 1
    ) {
        self.radians = radians
        self.axis = axis
        self.anchorZ = anchorZ
        self.perspective = perspective
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.radians == rhs.radians
            && lhs.axis == rhs.axis
            && lhs.anchorZ == rhs.anchorZ
            && lhs.perspective == rhs.perspective
    }

    /// Converts a Core Animation `m34` into SwiftUI's relative `perspective`.
    ///
    /// `m34 = 1 / -d` puts the eye `d` points from the plane; SwiftUI divides by
    /// `extent / perspective`, so `perspective = extent / d = extent * -m34`.
    public static func matchingM34(_ m34: CGFloat, extent: CGFloat) -> CGFloat {
        guard m34 != 0 else { return 0 }
        return extent * -m34
    }
}

/// A declarative subset of `CATransform3D`.
///
/// The composition is fixed at `scale . rotate . translate`, so `translation`
/// is expressed in unscaled model space and then scaled -- matching
/// `CATransform3DTranslate(CATransform3DScale(...))`. An effect that wants the
/// translation applied *after* the rotation cannot be written directly; rotate
/// the translation vector backwards instead.
///
/// Deliberately not a matrix: SwiftUI cannot consume `CATransform3D`, and
/// `ProjectionTransform` is 3x3 with no perspective w-divide. A layout needing
/// shear plus perspective plus an off-centre 3D anchor cannot be expressed here.
public struct StackEffect: Equatable, Sendable {
    public var scale: CGSize
    public var scaleAnchor: CGPoint
    /// Applied *before* `scale`, matching `CATransform3DTranslate(CATransform3DScale(...))`.
    public var translation: CGSize
    public var rotation: StackRotation3D?
    public var opacity: Double
    public var zIndex: Double
    public var projection: CGAffineTransform

    public init(
        scale: CGSize = CGSize(width: 1, height: 1),
        scaleAnchor: CGPoint = CGPoint(x: 0.5, y: 0.5),
        translation: CGSize = .zero,
        rotation: StackRotation3D? = nil,
        opacity: Double = 1,
        zIndex: Double = 0,
        projection: CGAffineTransform = .identity
    ) {
        self.scale = scale
        self.scaleAnchor = scaleAnchor
        self.translation = translation
        self.rotation = rotation
        self.opacity = opacity
        self.zIndex = zIndex
        self.projection = projection
    }

    public static let identity = StackEffect()

    public var isIdentity: Bool { self == .identity }
}
