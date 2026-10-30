import Combine

/// A type-erased tweak, used to list tweaks in the UI.
public protocol AnyTweak: Sendable {
    var collection: String { get }
    var group: String { get }
    var name: String { get }
    var control: TweakControl { get }
}

public extension AnyTweak {
    var id: String { "\(collection)|\(group)|\(name)" }
}

/// The UI edits value tweaks through their primitive form.
protocol PrimitiveTweak: AnyTweak {
    var primitiveValue: TweakPrimitive { get nonmutating set }
    var defaultPrimitive: TweakPrimitive { get }
    var primitivePublisher: AnyPublisher<TweakPrimitive, Never> { get }
    func reset()
}

/// A value that you can change at runtime from the tweaks UI.
public struct Tweak<Value: TweakValue>: AnyTweak {
    public let collection: String
    public let group: String
    public let name: String
    public let defaultValue: Value
    public let control: TweakControl
    let store: TweakStore
    let normalize: @Sendable (Value) -> Value

    public init(
        collection: String,
        group: String,
        name: String,
        defaultValue: Value,
        store: TweakStore = .shared
    ) {
        self.init(collection, group, name, defaultValue, Value.control, store) { $0 }
    }

    private init(
        _ collection: String,
        _ group: String,
        _ name: String,
        _ defaultValue: Value,
        _ control: TweakControl,
        _ store: TweakStore,
        normalize: @escaping @Sendable (Value) -> Value
    ) {
        self.collection = collection
        self.group = group
        self.name = name
        self.defaultValue = defaultValue
        self.control = control
        self.store = store
        self.normalize = normalize
    }

    public var value: Value {
        get { store.value(for: self) }
        nonmutating set { store.setValue(newValue, for: self) }
    }

    /// Publishes the current value, then each change.
    public var publisher: AnyPublisher<Value, Never> { store.publisher(for: self) }

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
        store: TweakStore = .shared
    ) {
        assert((min ... max).contains(defaultValue), "Tweak \"\(name)\": defaultValue must be in min...max.")
        let range = min.primitive.doubleValue.flatMap { lower in
            max.primitive.doubleValue.map { lower ... $0 }
        }
        self.init(collection, group, name, defaultValue, .number(range: range), store) {
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
        store: TweakStore = .shared
    ) {
        assert(options.contains(defaultValue), "Tweak \"\(name)\": defaultValue must be one of the options.")
        self.init(collection, group, name, defaultValue, .picker(options: options), store) {
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

    var primitivePublisher: AnyPublisher<TweakPrimitive, Never> {
        publisher.map(\.primitive).eraseToAnyPublisher()
    }
}

/// A tweak that runs a closure when you tap it in the tweaks UI.
public struct TweakAction: AnyTweak {
    public let collection: String
    public let group: String
    public let name: String
    public var control: TweakControl { .action }
    private let run: @MainActor @Sendable () -> Void

    public init(
        collection: String,
        group: String,
        name: String,
        run: @escaping @MainActor @Sendable () -> Void
    ) {
        self.collection = collection
        self.group = group
        self.name = name
        self.run = run
    }

    @MainActor
    public func callAsFunction() { run() }
}
