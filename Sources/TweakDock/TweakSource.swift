import Combine

/// Gives values for tweaks that have a `sourceKey`, for example from Remote Config or a local split.
///
/// A tweak uses a source value only when it is valid. When the source returns `nil`, or a value
/// that the tweak cannot hold, such as an unknown enum case or a number out of range, the tweak
/// uses its default value.
public protocol TweakSource: AnyObject, Sendable {
    /// The name that the tweaks UI and `TweakCurrentValue.source` show.
    var name: String { get }

    /// Returns the value for `key`, or `nil` when the source has no value.
    /// `kind` is the kind of the tweak default value. Use it to convert text values.
    func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive?

    /// Sends when the values can have changed, for example after Remote Config activates.
    var changes: AnyPublisher<Void, Never> { get }
}

public extension TweakSource {
    var changes: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
}

/// The current value of a tweak, and where it comes from.
///
/// To report an experiment, send `"default"` for `.default`, and the value for the other cases.
public enum TweakCurrentValue<Value: Sendable & Equatable>: Sendable, Equatable {
    /// No override and no valid source value.
    case `default`(Value)
    /// The value of the named source.
    case source(String, Value)
    /// A value that you set in the tweaks UI or in code.
    case override(Value)

    public var value: Value {
        switch self {
        case let .default(value), let .source(_, value), let .override(value): value
        }
    }

    func map<T>(_ transform: (Value) -> T) -> TweakCurrentValue<T> {
        switch self {
        case let .default(value): .default(transform(value))
        case let .source(name, value): .source(name, transform(value))
        case let .override(value): .override(transform(value))
        }
    }
}

/// The current value, and the source value that an override hides. The tweaks UI shows both.
struct TweakReading<Value: Sendable & Equatable>: Sendable, Equatable {
    let current: TweakCurrentValue<Value>
    let sourceValue: Value?
    let sourceName: String?

    var isOverride: Bool {
        if case .override = current { true } else { false }
    }

    func map<T>(_ transform: (Value) -> T) -> TweakReading<T> {
        TweakReading<T>(current: current.map(transform), sourceValue: sourceValue.map(transform), sourceName: sourceName)
    }
}

/// A source that keeps the name of the inner source that gives each value.
protocol NamedTweakSource {
    func namedPrimitive(forKey key: String, as kind: TweakPrimitive.Kind) -> (primitive: TweakPrimitive, sourceName: String)?
}

extension TweakSource {
    func lookup(_ key: String, as kind: TweakPrimitive.Kind) -> (primitive: TweakPrimitive, sourceName: String)? {
        if let named = self as? NamedTweakSource {
            return named.namedPrimitive(forKey: key, as: kind)
        }
        return primitive(forKey: key, as: kind).map { ($0, name) }
    }
}
