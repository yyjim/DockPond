import CoreGraphics
import Foundation

/// The storable form of a tweak value.
public enum TweakPrimitive: Codable, Hashable, Sendable {
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)

    public enum Kind: Sendable {
        case bool, int, double, string
    }

    public var kind: Kind {
        switch self {
        case .bool: .bool
        case .int: .int
        case .double: .double
        case .string: .string
        }
    }

    /// Parses a text value, such as a Remote Config string or a launch argument.
    /// Returns `nil` when the text is not a valid value of `kind`.
    public init?(string: String, as kind: Kind) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        switch kind {
        case .bool:
            switch trimmed.lowercased() {
            case "true", "yes", "1": self = .bool(true)
            case "false", "no", "0": self = .bool(false)
            default: return nil
            }
        case .int:
            guard let value = Int(trimmed) else { return nil }
            self = .int(value)
        case .double:
            guard let value = Double(trimmed), value.isFinite else { return nil }
            self = .double(value)
        case .string:
            self = .string(string)
        }
    }

    /// Converts text to `kind`, as Remote Config text needs.
    func converted(to kind: Kind) -> TweakPrimitive? {
        guard case let .string(text) = self, kind != .string else { return self }
        return TweakPrimitive(string: text, as: kind)
    }

    var doubleValue: Double? {
        switch self {
        case let .int(value): Double(value)
        case let .double(value): value
        case .bool, .string: nil
        }
    }
}

/// How the tweaks UI edits a tweak.
public enum TweakControl: Sendable, Equatable {
    case toggle
    case number(range: ClosedRange<Double>?)
    case text
    case picker(options: [String])
    case action
}

/// A type that a `Tweak` can hold.
///
/// `Bool`, `Int`, `Double`, `CGFloat`, and `String` conform out of the box.
/// A `String`-backed `CaseIterable` enum conforms with an empty extension.
public protocol TweakValue: Sendable, Equatable {
    init?(primitive: TweakPrimitive)
    var primitive: TweakPrimitive { get }
    static var control: TweakControl { get }
}

extension Bool: TweakValue {
    public init?(primitive: TweakPrimitive) {
        guard case let .bool(value) = primitive else { return nil }
        self = value
    }

    public var primitive: TweakPrimitive { .bool(self) }
    public static var control: TweakControl { .toggle }
}

extension Int: TweakValue {
    public init?(primitive: TweakPrimitive) {
        guard case let .int(value) = primitive else { return nil }
        self = value
    }

    public var primitive: TweakPrimitive { .int(self) }
    public static var control: TweakControl { .number(range: nil) }
}

extension Double: TweakValue {
    public init?(primitive: TweakPrimitive) {
        guard let value = primitive.doubleValue else { return nil }
        self = value
    }

    public var primitive: TweakPrimitive { .double(self) }
    public static var control: TweakControl { .number(range: nil) }
}

extension CGFloat: TweakValue {
    public init?(primitive: TweakPrimitive) {
        guard let value = primitive.doubleValue else { return nil }
        self = CGFloat(value)
    }

    public var primitive: TweakPrimitive { .double(Double(self)) }
    public static var control: TweakControl { .number(range: nil) }
}

extension String: TweakValue {
    public init?(primitive: TweakPrimitive) {
        guard case let .string(value) = primitive else { return nil }
        self = value
    }

    public var primitive: TweakPrimitive { .string(self) }
    public static var control: TweakControl { .text }
}

public extension TweakValue where Self: RawRepresentable & CaseIterable, RawValue == String {
    init?(primitive: TweakPrimitive) {
        guard case let .string(rawValue) = primitive else { return nil }
        self.init(rawValue: rawValue)
    }

    var primitive: TweakPrimitive { .string(rawValue) }
    static var control: TweakControl { .picker(options: allCases.map(\.rawValue)) }
}
