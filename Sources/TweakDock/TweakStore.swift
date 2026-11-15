import Combine
import CryptoKit
import Foundation

/// Keeps the values that override tweak defaults, and saves them to a JSON file.
public final class TweakStore: @unchecked Sendable {
    public static let shared = TweakStore()

    public let fileURL: URL
    private let lock = NSLock()
    private let writeLock = NSLock()
    private var overrides: [String: TweakPrimitive]
    private var enabled: Bool
    private var currentRemote: (any TweakValueProvider)?
    private var remoteSubscription: AnyCancellable?
    private var splitSeed: String?
    private let launchArguments: [String: String]
    private let device: TweakDevices
    /// Sends the changed tweak ID, or `nil` when every tweak can have changed.
    private let changes = PassthroughSubject<String?, Never>()

    /// Saves to `<name>.json` in Application Support, or in the app group container when you give `appGroup`.
    /// Use an app group to share tweaks with app extensions. Each process reads the file when it makes the store,
    /// and reads it again before each change, so processes keep the changes of the others.
    public convenience init(name: String = "Tweaks", appGroup: String? = nil, isEnabled: Bool = true) {
        self.init(fileURL: Self.fileURL(name: name, appGroup: appGroup), isEnabled: isEnabled)
    }

    public convenience init(fileURL: URL, isEnabled: Bool = true) {
        self.init(fileURL: fileURL, isEnabled: isEnabled, arguments: ProcessInfo.processInfo.arguments, device: .current)
    }

    init(fileURL: URL, isEnabled: Bool, arguments: [String], device: TweakDevices) {
        self.fileURL = fileURL
        enabled = isEnabled
        overrides = Self.load(from: fileURL)
        launchArguments = Self.tweakArguments(in: arguments)
        self.device = device
    }

    /// When `false`, the store ignores overrides and launch arguments. Each tweak returns its source
    /// value or its default value. Set it to `false` in release builds.
    public var isEnabled: Bool {
        get { lock.withLock { enabled } }
        set {
            lock.withLock { enabled = newValue }
            changes.send(nil)
        }
    }

    /// Gives the values of `.experiment` and `.config` tweaks. Set it at launch, for example to a Firebase
    /// Remote Config adapter.
    public var remote: (any TweakValueProvider)? {
        get { lock.withLock { currentRemote } }
        set {
            let subscription = newValue?.changes.sink { [weak self] in self?.changes.send(nil) }
            lock.withLock {
                currentRemote = newValue
                remoteSubscription = subscription
            }
            changes.send(nil)
        }
    }

    /// Gives this device new values in each `.localExperiment` and `.rollout`.
    public func resetSplits() {
        let seed = UUID().uuidString
        Self.saveSplitSeed(seed, next: fileURL)
        lock.withLock { splitSeed = seed }
        changes.send(nil)
    }

    public func resetAll() {
        withFileLock {
            save([:])
            lock.withLock { overrides.removeAll() }
        }
        changes.send(nil)
    }

    func value<Value>(for tweak: Tweak<Value>) -> Value {
        currentValue(for: tweak).value
    }

    func currentValue<Value>(for tweak: Tweak<Value>) -> TweakCurrentValue<Value> {
        let (override, state) = snapshot(for: tweak)
        if let value = override.flatMap(Value.init(primitive:)).map(tweak.normalize) { return .override(value) }
        return sourceValue(for: tweak, in: state).map { .source($0.name, $0.value) } ?? .default(tweak.defaultValue)
    }

    /// The valid source value, also when an override hides it. The tweaks UI shows it.
    func sourceValue<Value>(for tweak: Tweak<Value>) -> (name: String, value: Value)? {
        sourceValue(for: tweak, in: snapshot(for: tweak).state)
    }

    /// A tweak with a source keeps an override that equals its default value, because the
    /// override hides the source value.
    func setValue<Value>(_ value: Value, for tweak: Tweak<Value>) {
        let value = tweak.normalize(value)
        let isRedundant = tweak.source == nil && value == tweak.defaultValue
        setOverride(isRedundant ? nil : value.primitive, id: tweak.id)
    }

    private struct SourceState {
        let isEnabled: Bool
        let remote: (any TweakValueProvider)?
    }

    private func snapshot(for tweak: some AnyTweak) -> (override: TweakPrimitive?, state: SourceState) {
        lock.withLock { (enabled ? overrides[tweak.id] : nil, SourceState(isEnabled: enabled, remote: currentRemote)) }
    }

    /// Uses a launch argument, then the source of the tweak. A value that the tweak would change,
    /// such as a number out of range, is not valid, and the next step is used.
    private func sourceValue<Value>(for tweak: Tweak<Value>, in state: SourceState) -> (name: String, value: Value)? {
        guard let source = tweak.source else { return nil }
        let kind = tweak.defaultValue.primitive.kind
        func valid(_ primitive: TweakPrimitive?) -> Value? {
            primitive.flatMap(Value.init(primitive:)).flatMap { tweak.normalize($0) == $0 ? $0 : nil }
        }
        if state.isEnabled, let value = valid(launchArguments[source.key].flatMap { TweakPrimitive(string: $0, as: kind) }) {
            return ("Launch Argument", value)
        }
        guard source.devices.contains(device) else { return nil }
        switch source.kind {
        case .remote:
            guard let remote = state.remote, let value = valid(remote.primitive(forKey: source.key, as: kind)) else { return nil }
            return (remote.name, value)
        case let .custom(provider):
            return valid(provider.primitive(forKey: source.key, as: kind)).map { (provider.name, $0) }
        case let .split(weights):
            let bucket = Self.splitBucket(seed: currentSplitSeed(), key: source.key)
            return valid(Self.splitValue(weights, at: bucket)?.converted(to: kind)).map { ("Local Split", $0) }
        }
    }

    private func currentSplitSeed() -> String {
        lock.withLock {
            if let splitSeed { return splitSeed }
            let seed = Self.loadSplitSeed(next: fileURL)
            splitSeed = seed
            return seed
        }
    }

    static func splitValue(_ weights: [(value: TweakPrimitive, weight: Double)], at bucket: Double) -> TweakPrimitive? {
        let target = bucket * weights.reduce(0) { $0 + $1.weight }
        var total = 0.0
        for (value, weight) in weights {
            total += weight
            if target < total { return value }
        }
        return weights.last?.value
    }

    /// A number from 0 to 1 that does not change for a seed and a key.
    static func splitBucket(seed: String, key: String) -> Double {
        let digest = SHA256.hash(data: Data("\(seed).\(key)".utf8))
        let number = digest.prefix(8).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        return Double(number >> 11) / Double(UInt64(1) << 53)
    }

    func reset(_ tweak: some AnyTweak) {
        setOverride(nil, id: tweak.id)
    }

    func publisher<Value>(for tweak: Tweak<Value>) -> AnyPublisher<Value, Never> {
        currentValuePublisher(for: tweak).map(\.value).removeDuplicates().eraseToAnyPublisher()
    }

    func currentValuePublisher<Value>(for tweak: Tweak<Value>) -> AnyPublisher<TweakCurrentValue<Value>, Never> {
        changeSignal(for: tweak).map { [self] in currentValue(for: tweak) }.removeDuplicates().eraseToAnyPublisher()
    }

    /// Sends one time when you subscribe, then each time that the tweak can have changed.
    func changeSignal<Value>(for tweak: Tweak<Value>) -> AnyPublisher<Void, Never> {
        var providerChanges = Empty<Void, Never>().eraseToAnyPublisher()
        if case let .custom(provider) = tweak.source?.kind {
            providerChanges = provider.changes
        }
        return changes
            .filter { $0 == nil || $0 == tweak.id }
            .map { _ in }
            .merge(with: providerChanges)
            .merge(with: Just(()))
            .eraseToAnyPublisher()
    }

    private func setOverride(_ primitive: TweakPrimitive?, id: String) {
        let changedIDs = withFileLock {
            let saved = Self.load(from: fileURL)
            var updated = saved
            updated[id] = primitive
            if updated != saved {
                save(updated)
            }
            return lock.withLock {
                let previous = overrides
                overrides = updated
                return Set(previous.keys).union(updated.keys).filter { previous[$0] != updated[$0] }
            }
        }
        if changedIDs == [id] {
            changes.send(id)
        } else if !changedIDs.isEmpty {
            changes.send(nil)
        }
    }

    /// `writeLock` guards only this instance. Another process, or another store of the
    /// same file, can save between a read and a write, so an advisory file lock guards
    /// the whole change. `lock` is not held while this waits, so reads do not wait for
    /// another process.
    private func withFileLock<T>(_ body: () -> T) -> T {
        writeLock.lock()
        defer { writeLock.unlock() }
        let lockPath = fileURL.path + ".lock"
        var descriptor = open(lockPath, O_CREAT | O_RDWR, 0o644)
        if descriptor < 0, errno == ENOENT {
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            descriptor = open(lockPath, O_CREAT | O_RDWR, 0o644)
        }
        guard descriptor >= 0 else { return body() }
        defer { close(descriptor) }
        while flock(descriptor, LOCK_EX) != 0, errno == EINTR {}
        defer { flock(descriptor, LOCK_UN) }
        return body()
    }

    /// Reads `-tweak.<key> <value>` pairs. A value that starts with the prefix is the next pair, not a value.
    static func tweakArguments(in arguments: [String], prefix: String = "-tweak.") -> [String: String] {
        var values: [String: String] = [:]
        for (argument, value) in zip(arguments, arguments.dropFirst())
            where argument.hasPrefix(prefix) && !value.hasPrefix(prefix) {
            values[String(argument.dropFirst(prefix.count))] = value
        }
        return values
    }

    /// The seed is next to the tweaks file, so that app extensions in the same app group get the same splits.
    private static func loadSplitSeed(next fileURL: URL) -> String {
        let seedURL = fileURL.appendingPathExtension("seed")
        if let seed = try? String(contentsOf: seedURL, encoding: .utf8), !seed.isEmpty {
            return seed
        }
        let seed = UUID().uuidString
        try? FileManager.default.createDirectory(at: seedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if (try? Data(seed.utf8).write(to: seedURL, options: .withoutOverwriting)) == nil,
           let saved = try? String(contentsOf: seedURL, encoding: .utf8), !saved.isEmpty {
            return saved
        }
        return seed
    }

    private static func saveSplitSeed(_ seed: String, next fileURL: URL) {
        try? Data(seed.utf8).write(to: fileURL.appendingPathExtension("seed"), options: .atomic)
    }

    private static func load(from fileURL: URL) -> [String: TweakPrimitive] {
        (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode([String: TweakPrimitive].self, from: $0) } ?? [:]
    }

    private func save(_ overrides: [String: TweakPrimitive]) {
        do {
            try JSONEncoder().encode(overrides).write(to: fileURL, options: .atomic)
        } catch {
            assertionFailure("TweakDock could not save to \(fileURL.path): \(error)")
        }
    }

    private static func fileURL(name: String, appGroup: String?) -> URL {
        let directory: URL
        if let appGroup {
            guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) else {
                preconditionFailure("App group '\(appGroup)' is not available. Add it to the App Groups entitlement.")
            }
            directory = container
        } else {
            directory = URL.applicationSupportDirectory
        }
        return directory.appending(components: "TweakDock", "\(name).json")
    }
}
