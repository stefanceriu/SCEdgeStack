import StackGeometry

/// Public addressing for a stacked child.
///
/// Defaults to `.position(edge, index)`; `.stackID(_:)` overrides it with
/// anything `Hashable`.
public struct StackItemID: Hashable, Sendable {
    /// `AnyHashable` is not `Sendable`, but every value that reaches this box
    /// was `Sendable` on the way in.
    struct AnyHashableSendable: Hashable, @unchecked Sendable {
        let base: AnyHashable
        init(_ value: some Hashable & Sendable) { base = AnyHashable(value) }
    }

    enum Storage: Hashable, Sendable {
        case root
        case position(StackEdge, Int)
        case custom(AnyHashableSendable)
    }

    let storage: Storage

    public static let root = StackItemID(storage: .root)

    public static func position(_ edge: StackEdge, _ index: Int) -> StackItemID {
        StackItemID(storage: .position(edge, index))
    }

    public init(_ value: some Hashable & Sendable) {
        storage = .custom(AnyHashableSendable(value))
    }

    init(storage: Storage) {
        self.storage = storage
    }
}

extension StackItemID: CustomStringConvertible {
    public var description: String {
        switch storage {
        case .root: "root"
        case let .position(edge, index): "\(edge)[\(index)]"
        case let .custom(value): "\(value.base.base)"
        }
    }
}
