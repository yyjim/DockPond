import Combine
import Foundation

/// Puts each device in a local bucket for each key, and gives the value of that bucket.
///
/// Use it for an experiment or a rollout that has no server. When you make the source, it keeps
/// a random number from 0 to 1 for each new key in `UserDefaults`, so a device keeps its value.
/// When you increase a rollout fraction, the devices that had the value keep it.
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
        for key in splits.keys where bucket(forKey: key) == nil {
            defaults.set(Double.random(in: 0 ..< 1), forKey: keyPrefix + key)
        }
    }

    public func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? {
        guard let split = splits[key], let bucket = bucket(forKey: key) else { return nil }
        return split.value(at: bucket).converted(to: kind)
    }

    /// Puts this device in new random buckets.
    public func reassignAll() {
        for key in splits.keys {
            defaults.set(Double.random(in: 0 ..< 1), forKey: keyPrefix + key)
        }
        subject.send()
    }

    public var changes: AnyPublisher<Void, Never> { subject.eraseToAnyPublisher() }

    private func bucket(forKey key: String) -> Double? {
        (defaults.object(forKey: keyPrefix + key) as? Double).flatMap { (0 ..< 1).contains($0) ? $0 : nil }
    }
}
