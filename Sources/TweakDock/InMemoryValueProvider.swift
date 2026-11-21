/// Gives fixed values. Use it for tests and previews.
///
/// A `.string` value converts to the kind of the tweak, as Remote Config text does.
public final class InMemoryValueProvider: TweakValueProvider {
    public let name: String
    private let values: [String: TweakPrimitive]

    public init(name: String, values: [String: TweakPrimitive] = [:]) {
        self.name = name
        self.values = values
    }

    public func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? {
        values[key]?.converted(to: kind)
    }
}
