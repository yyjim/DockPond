import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Asks each source in order, and uses the first value that the tweak can hold.
///
/// `TweakCurrentValue.source` gives the name of the inner source that gives the value.
public final class CombinedTweakSource: TweakSource, NamedTweakSource {
    public let name: String
    public let sources: [any TweakSource]

    public init(name: String = "Combined", _ sources: [any TweakSource]) {
        self.name = name
        self.sources = sources
    }

    public func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? {
        namedPrimitive(forKey: key, as: kind, accepts: { _ in true })?.primitive
    }

    func namedPrimitive(
        forKey key: String, as kind: TweakPrimitive.Kind, accepts: (TweakPrimitive) -> Bool
    ) -> (primitive: TweakPrimitive, sourceName: String)? {
        for source in sources {
            if let value = source.lookup(key, as: kind, accepts: accepts) { return value }
        }
        return nil
    }

    public var changes: AnyPublisher<Void, Never> {
        Publishers.MergeMany(sources.map(\.changes)).eraseToAnyPublisher()
    }
}

/// Keeps values in memory. Use it for tests, previews, or a fake remote config.
///
/// A `.string` value converts to the kind of the tweak, as Remote Config text does.
public final class InMemoryTweakSource: TweakSource, @unchecked Sendable {
    public let name: String
    private let lock = NSLock()
    private var values: [String: TweakPrimitive]
    private let subject = PassthroughSubject<Void, Never>()

    public init(name: String, values: [String: TweakPrimitive] = [:]) {
        self.name = name
        self.values = values
    }

    public func setValue(_ value: TweakPrimitive?, forKey key: String) {
        lock.withLock { values[key] = value }
        subject.send()
    }

    public func replaceValues(_ newValues: [String: TweakPrimitive]) {
        lock.withLock { values = newValues }
        subject.send()
    }

    public func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? {
        lock.withLock { values[key] }?.converted(to: kind)
    }

    public var changes: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }
}

/// Reads values from launch arguments, such as `-tweak.exp_paywall B`. Use it to set values in UI tests.
public final class LaunchArgumentTweakSource: TweakSource {
    public let name: String
    private let values: [String: String]

    public init(name: String = "Launch Argument", prefix: String = "-tweak.", arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.name = name
        var values: [String: String] = [:]
        for (argument, value) in zip(arguments, arguments.dropFirst())
            where argument.hasPrefix(prefix) && !value.hasPrefix(prefix) {
            values[String(argument.dropFirst(prefix.count))] = value
        }
        self.values = values
    }

    public func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? {
        values[key].flatMap { TweakPrimitive(string: $0, as: kind) }
    }
}

/// Puts each device in a local bucket for each key, and gives the value of that bucket.
///
/// Use it for an experiment or a rollout that has no server. The source keeps a random
/// number from 0 to 1 for each key in `UserDefaults`, so a device keeps its value. When you
/// increase a rollout fraction, the devices that had the value keep it.
public final class LocalSplitTweakSource: TweakSource, @unchecked Sendable {
    public struct Split: Sendable {
        let weights: [(value: TweakPrimitive, weight: Double)]

        public init(_ weights: [(value: TweakPrimitive, weight: Double)]) {
            precondition(weights.contains { $0.weight > 0 }, "A split needs a weight that is more than 0.")
            self.weights = weights
        }

        /// Gives variants in proportion to their weights. A variant is the raw value of an enum case, or the
        /// text of a number or a Boolean value.
        public static func variants(_ weights: KeyValuePairs<String, Double>) -> Split {
            Split(weights.map { (TweakPrimitive.string($0.key), $0.value) })
        }

        /// Gives `true` to `fraction` of the devices, and `false` to the others.
        public static func rollout(_ fraction: Double) -> Split {
            let fraction = min(max(fraction, 0), 1)
            return Split([(.bool(true), fraction), (.bool(false), 1 - fraction)])
        }

        func value(at bucket: Double) -> TweakPrimitive {
            let weights = weights.filter { $0.weight > 0 }
            let target = bucket * weights.reduce(0) { $0 + $1.weight }
            var total = 0.0
            for (value, weight) in weights {
                total += weight
                if target < total { return value }
            }
            return weights[weights.count - 1].value
        }
    }

    public let name: String
    private let splits: [String: Split]
    private let defaults: UserDefaults
    private let keyPrefix: String
    private let lock = NSLock()
    private let subject = PassthroughSubject<Void, Never>()

    public init(
        name: String = "Local Split",
        splits: [String: Split],
        defaults: UserDefaults = .standard,
        keyPrefix: String = "TweakDock.split."
    ) {
        self.name = name
        self.splits = splits
        self.defaults = defaults
        self.keyPrefix = keyPrefix
    }

    public func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? {
        guard let split = splits[key] else { return nil }
        return split.value(at: bucket(forKey: key)).converted(to: kind)
    }

    /// Puts this device in new random buckets. The next read gives the new values.
    public func reassignAll() {
        lock.withLock {
            splits.keys.forEach { defaults.removeObject(forKey: keyPrefix + $0) }
        }
        subject.send()
    }

    public var changes: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }

    private func bucket(forKey key: String) -> Double {
        lock.withLock {
            let storageKey = keyPrefix + key
            if let bucket = defaults.object(forKey: storageKey) as? Double, (0 ..< 1).contains(bucket) {
                return bucket
            }
            let bucket = Double.random(in: 0 ..< 1)
            defaults.set(bucket, forKey: storageKey)
            return bucket
        }
    }
}

#if canImport(UIKit)
/// Gives the values of `base` only on the given devices. On other devices, a tweak uses its default value.
///
/// Keys that are not in `devices` work on all devices.
public final class DeviceTweakSource: TweakSource, NamedTweakSource {
    public let base: any TweakSource
    public let idiom: UIUserInterfaceIdiom
    private let devices: [String: Set<UIUserInterfaceIdiom>]

    public init(_ base: any TweakSource, devices: [String: Set<UIUserInterfaceIdiom>], idiom: UIUserInterfaceIdiom) {
        self.base = base
        self.devices = devices
        self.idiom = idiom
    }

    @MainActor
    public convenience init(_ base: any TweakSource, devices: [String: Set<UIUserInterfaceIdiom>]) {
        self.init(base, devices: devices, idiom: UIDevice.current.userInterfaceIdiom)
    }

    public var name: String { base.name }

    public func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? {
        namedPrimitive(forKey: key, as: kind, accepts: { _ in true })?.primitive
    }

    func namedPrimitive(
        forKey key: String, as kind: TweakPrimitive.Kind, accepts: (TweakPrimitive) -> Bool
    ) -> (primitive: TweakPrimitive, sourceName: String)? {
        guard devices[key].map({ $0.contains(idiom) }) ?? true else { return nil }
        return base.lookup(key, as: kind, accepts: accepts)
    }

    public var changes: AnyPublisher<Void, Never> { base.changes }
}
#endif
