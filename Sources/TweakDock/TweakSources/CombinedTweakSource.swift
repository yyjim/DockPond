import Combine

/// Asks each source in order. A tweak uses the first value that it can hold, and
/// `TweakCurrentValue.source` gives the name of the inner source that gives it.
public final class CombinedTweakSource: TweakSource, NamedTweakSource {
    public let name: String
    public let sources: [any TweakSource]

    public init(name: String = "Combined", _ sources: [any TweakSource]) {
        self.name = name
        self.sources = sources
    }

    public func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? {
        namedValue(forKey: key, as: kind) { $0 }?.value
    }

    func namedValue<T>(
        forKey key: String, as kind: TweakPrimitive.Kind, transform: (TweakPrimitive) -> T?
    ) -> (value: T, sourceName: String)? {
        for source in sources {
            if let value = source.lookup(key, as: kind, transform: transform) { return value }
        }
        return nil
    }

    public var changes: AnyPublisher<Void, Never> {
        Publishers.MergeMany(sources.map(\.changes)).eraseToAnyPublisher()
    }
}
