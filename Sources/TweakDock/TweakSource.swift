import Combine

/// Gives the values of `.remote` tweaks. Set it as `TweakStore.remote`, for example to a Firebase Remote Config adapter.
///
/// A tweak uses a value only when it is valid. When the source returns `nil`, or a value that the
/// tweak cannot hold, such as an unknown enum case or a number out of range, the tweak uses its
/// default value.
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

    var isOverride: Bool {
        if case .override = self { true } else { false }
    }

    func map<T>(_ transform: (Value) -> T) -> TweakCurrentValue<T> {
        switch self {
        case let .default(value): .default(transform(value))
        case let .source(name, value): .source(name, transform(value))
        case let .override(value): .override(transform(value))
        }
    }
}
