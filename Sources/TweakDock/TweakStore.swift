import Combine
import Foundation

/// Keeps the values that override tweak defaults, and saves them to a JSON file.
public final class TweakStore: @unchecked Sendable {
    public static let shared = TweakStore()

    public let fileURL: URL
    private let lock = NSLock()
    private let writeLock = NSLock()
    private var overrides: [String: TweakPrimitive]
    private var enabled: Bool
    private var currentSource: (any TweakSource)?
    private var sourceSubscription: AnyCancellable?
    /// Sends the changed tweak ID, or `nil` when every tweak can have changed.
    private let changes = PassthroughSubject<String?, Never>()

    /// Saves to `<name>.json` in Application Support, or in the app group container when you give `appGroup`.
    /// Use an app group to share tweaks with app extensions. Each process reads the file when it makes the store,
    /// and reads it again before each change, so processes keep the changes of the others.
    public convenience init(name: String = "Tweaks", appGroup: String? = nil, isEnabled: Bool = true) {
        self.init(fileURL: Self.fileURL(name: name, appGroup: appGroup), isEnabled: isEnabled)
    }

    public init(fileURL: URL, isEnabled: Bool = true) {
        self.fileURL = fileURL
        enabled = isEnabled
        overrides = Self.load(from: fileURL)
    }

    /// When `false`, the store ignores overrides. Each tweak returns its source value or its
    /// default value. Set it to `false` in release builds.
    public var isEnabled: Bool {
        get { lock.withLock { enabled } }
        set {
            lock.withLock { enabled = newValue }
            changes.send(nil)
        }
    }

    /// Gives values to tweaks that have a `sourceKey`. Set it at launch, for example to a Remote Config adapter.
    /// An override hides the source value until you reset the tweak.
    public var source: (any TweakSource)? {
        get { lock.withLock { currentSource } }
        set {
            let subscription = newValue?.changes.sink { [weak self] in self?.changes.send(nil) }
            lock.withLock {
                currentSource = newValue
                sourceSubscription = subscription
            }
            changes.send(nil)
        }
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
        let (override, source) = snapshot(for: tweak)
        if let override { return .override(override) }
        return current(sourced: sourced(for: tweak, from: source), tweak: tweak)
    }

    func reading<Value>(for tweak: Tweak<Value>) -> TweakReading<Value> {
        let (override, source) = snapshot(for: tweak)
        let sourced = sourced(for: tweak, from: source)
        return TweakReading(current: override.map { .override($0) } ?? current(sourced: sourced, tweak: tweak), source: sourced)
    }

    /// A tweak with a `sourceKey` keeps an override that equals its default value, because the
    /// override hides the source value.
    func setValue<Value>(_ value: Value, for tweak: Tweak<Value>) {
        let value = tweak.normalize(value)
        let isRedundant = tweak.sourceKey == nil && value == tweak.defaultValue
        setOverride(isRedundant ? nil : value.primitive, id: tweak.id)
    }

    private func snapshot<Value>(for tweak: Tweak<Value>) -> (override: Value?, source: (any TweakSource)?) {
        let (primitive, source) = lock.withLock { (enabled ? overrides[tweak.id] : nil, currentSource) }
        return (primitive.flatMap(Value.init(primitive:)).map(tweak.normalize), source)
    }

    /// A source value that the tweak would change, such as a number out of range, is not valid.
    private func sourced<Value>(for tweak: Tweak<Value>, from source: (any TweakSource)?) -> TweakReading<Value>.Sourced? {
        guard let key = tweak.sourceKey, let source else { return nil }
        let found = source.lookup(key, as: tweak.defaultValue.primitive.kind) { primitive in
            Value(primitive: primitive).flatMap { tweak.normalize($0) == $0 ? $0 : nil }
        }
        return found.map { TweakReading<Value>.Sourced(name: $0.sourceName, value: $0.value) }
    }

    private func current<Value>(sourced: TweakReading<Value>.Sourced?, tweak: Tweak<Value>) -> TweakCurrentValue<Value> {
        sourced.map { .source($0.name, $0.value) } ?? .default(tweak.defaultValue)
    }

    func reset(_ tweak: some AnyTweak) {
        setOverride(nil, id: tweak.id)
    }

    func publisher<Value>(for tweak: Tweak<Value>) -> AnyPublisher<Value, Never> {
        readingPublisher(for: tweak).map(\.current.value).removeDuplicates().eraseToAnyPublisher()
    }

    func readingPublisher<Value>(for tweak: Tweak<Value>) -> AnyPublisher<TweakReading<Value>, Never> {
        changes
            .filter { $0 == nil || $0 == tweak.id }
            .map { _ in }
            .merge(with: Just(()))
            .map { [self] in reading(for: tweak) }
            .removeDuplicates()
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
