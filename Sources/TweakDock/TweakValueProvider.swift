import Combine

/// Gives the values of `.experiment` and `.config` tweaks. Set it as `TweakStore.remote`, for example to a
/// Firebase Remote Config adapter. A `.custom` tweak uses its own provider.
///
/// A tweak uses a value only when it is valid. When the provider returns `nil`, or a value that the
/// tweak cannot hold, such as an unknown enum case or a number out of range, the tweak uses its
/// default value.
public protocol TweakValueProvider: AnyObject, Sendable {
    /// The name that the tweaks UI and `TweakCurrentValue.source` show.
    var name: String { get }

    /// Returns the value for `key`, or `nil` when the provider has no value.
    /// `kind` is the kind of the tweak default value. Use it to convert text values.
    func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive?

    /// Sends when the values can have changed, for example after Remote Config activates.
    var changes: AnyPublisher<Void, Never> { get }
}

public extension TweakValueProvider {
    var changes: AnyPublisher<Void, Never> { Empty().eraseToAnyPublisher() }
}
