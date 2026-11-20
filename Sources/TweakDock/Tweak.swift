import Combine

/// A type-erased tweak, used to list tweaks in the UI.
public protocol AnyTweak: Sendable {
    var collection: String { get }
    var group: String { get }
    var name: String { get }
    var control: TweakControl { get }
}

public extension AnyTweak {
    var id: String {
        [collection, group, name]
            .map { $0.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "|", with: "\\|") }
            .joined(separator: "|")
    }
}

protocol StoredTweak: AnyTweak {
    var store: TweakStore { get }
}

/// The UI edits value tweaks through their primitive form.
protocol PrimitiveTweak: StoredTweak {
    var source: TweakSource? { get }
    var primitiveValue: TweakPrimitive { get nonmutating set }
    var defaultPrimitive: TweakPrimitive { get }
    var primitiveCurrentValue: TweakCurrentValue<TweakPrimitive> { get }
    var primitiveSourceValue: (name: String, value: TweakPrimitive)? { get }
    var changeSignal: AnyPublisher<Void, Never> { get }
    var experimentProperty: (key: String, value: String)? { get }
    func reset()
}

/// A value that you can change at runtime from the tweaks UI.
public struct Tweak<Value: TweakValue>: AnyTweak {
    public let collection: String
    public let group: String
    public let name: String
    public let defaultValue: Value
    /// Where the tweak reads its value when no override exists. When it is `nil`, the tweak uses only its default value.
    public let source: TweakSource?
    public let control: TweakControl
    let store: TweakStore
    let normalize: @Sendable (Value) -> Value

    public init(
        collection: String,
        group: String,
        name: String,
        defaultValue: Value,
        from source: TweakSource? = nil,
        store: TweakStore = .shared
    ) {
        self.init(collection, group, name, defaultValue, source, Value.control, store) { $0 }
    }

    private init(
        _ collection: String,
        _ group: String,
        _ name: String,
        _ defaultValue: Value,
        _ source: TweakSource?,
        _ control: TweakControl,
        _ store: TweakStore,
        normalize: @escaping @Sendable (Value) -> Value
    ) {
        self.collection = collection
        self.group = group
        self.name = name
        self.defaultValue = defaultValue
        self.source = source
        self.control = control
        self.store = store
        self.normalize = normalize
    }

    public var value: Value {
        get { store.value(for: self) }
        nonmutating set { store.setValue(newValue, for: self) }
    }

    /// The current value, and where it comes from: `.default`, `.source`, or `.override`.
    public var currentValue: TweakCurrentValue<Value> { store.currentValue(for: self) }

    /// Publishes the current value, then each change.
    public var publisher: AnyPublisher<Value, Never> { store.publisher(for: self) }

    /// Publishes `currentValue`, then each change. It also publishes when only the source of the value changes.
    public var currentValuePublisher: AnyPublisher<TweakCurrentValue<Value>, Never> {
        store.currentValuePublisher(for: self)
    }

    public func reset() { store.reset(self) }
}

public extension Tweak where Value: Comparable & Numeric {
    init(
        collection: String,
        group: String,
        name: String,
        min: Value,
        max: Value,
        defaultValue: Value,
        from source: TweakSource? = nil,
        store: TweakStore = .shared
    ) {
        precondition(min <= max, "Tweak \"\(name)\": min must not be greater than max.")
        assert((min...max).contains(defaultValue), "Tweak \"\(name)\": defaultValue must be in min...max.")
        let range = min.primitive.doubleValue.flatMap { lower in
            max.primitive.doubleValue.map { lower...$0 }
        }
        self.init(collection, group, name, defaultValue, source, .number(range: range), store) {
            Swift.min(Swift.max($0, min), max)
        }
    }
}

public extension Tweak where Value == String {
    init(
        collection: String,
        group: String,
        name: String,
        options: [String],
        defaultValue: String,
        from source: TweakSource? = nil,
        store: TweakStore = .shared
    ) {
        assert(options.contains(defaultValue), "Tweak \"\(name)\": defaultValue must be one of the options.")
        self.init(collection, group, name, defaultValue, source, .picker(options: options), store) {
            options.contains($0) ? $0 : defaultValue
        }
    }
}

extension Tweak: PrimitiveTweak {
    var primitiveValue: TweakPrimitive {
        get { value.primitive }
        nonmutating set {
            if let newValue = Value(primitive: newValue) {
                value = newValue
            }
        }
    }

    var defaultPrimitive: TweakPrimitive { defaultValue.primitive }

    var primitiveCurrentValue: TweakCurrentValue<TweakPrimitive> { currentValue.map(\.primitive) }

    var primitiveSourceValue: (name: String, value: TweakPrimitive)? {
        store.sourceValue(for: self).map { ($0.name, $0.value.primitive) }
    }

    var changeSignal: AnyPublisher<Void, Never> { store.changeSignal(for: self) }

    var experimentProperty: (key: String, value: String)? {
        guard let source else { return nil }
        let current = primitiveCurrentValue
        if case .default = current { return (source.key, "default") }
        return (source.key, current.value.text)
    }
}

/// A tweak that runs a closure when you tap it in the tweaks UI.
public struct TweakAction: StoredTweak {
    public let collection: String
    public let group: String
    public let name: String
    public var control: TweakControl { .action }
    let store: TweakStore
    private let run: @MainActor @Sendable () -> Void

    public init(
        collection: String,
        group: String,
        name: String,
        store: TweakStore = .shared,
        run: @escaping @MainActor @Sendable () -> Void
    ) {
        self.collection = collection
        self.group = group
        self.name = name
        self.store = store
        self.run = run
    }

    @MainActor
    public func callAsFunction() { run() }
}

public extension Sequence where Element == any AnyTweak {
    /// The experiments to report to analytics, by key. Each value is the current value, or `"default"` when
    /// no valid source value or override exists. Only tweaks with `from: .experiment(...)` are in it.
    var experimentProperties: [String: String] {
        Dictionary(compactMap { ($0 as? any PrimitiveTweak)?.experimentProperty }) { first, _ in first }
    }
}

extension Sequence where Element == any AnyTweak {
    var hasEnabledStore: Bool {
        contains { ($0 as? any StoredTweak)?.store.isEnabled == true }
    }
}
