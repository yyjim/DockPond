/// The current value of a tweak, and where it comes from.
///
/// To report experiments, use `experimentProperties` on the list of tweaks.
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
