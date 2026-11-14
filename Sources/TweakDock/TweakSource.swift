import Combine

/// Gives values for tweaks that have a `sourceKey`, for example from Remote Config or a local split.
///
/// A tweak uses a source value only when it is valid. When the source returns `nil`, or a value
/// that the tweak cannot hold, such as an unknown enum case or a number out of range, the tweak
/// uses its default value.
public protocol TweakSource: AnyObject, Sendable {
    /// The name that the tweaks UI and `TweakOrigin.source` show.
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

/// Where the current value of a tweak comes from.
public enum TweakOrigin: Sendable, Hashable {
    /// No override and no valid source value.
    case `default`
    /// The value of the named source.
    case source(String)
    /// A value that you set in the tweaks UI or in code.
    case override
}

/// The value of a tweak, and where it comes from.
public struct TweakResolution<Value: Sendable & Equatable>: Sendable, Equatable {
    public let value: Value
    public let origin: TweakOrigin
    /// The valid source value, also when an override hides it.
    public let sourceValue: Value?
    /// The name of the source that gives `sourceValue`.
    public let sourceName: String?

    func map<T>(_ transform: (Value) -> T) -> TweakResolution<T> {
        TweakResolution<T>(value: transform(value), origin: origin, sourceValue: sourceValue.map(transform), sourceName: sourceName)
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
