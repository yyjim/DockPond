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
        resolution(for: tweak).value
    }

    func resolution<Value>(for tweak: Tweak<Value>) -> TweakResolution<Value> {
        let (override, source) = lock.withLock { (enabled ? overrides[tweak.id] : nil, currentSource) }
        let sourced = tweak.sourceKey
            .flatMap { source?.lookup($0, as: tweak.defaultValue.primitive.kind) }
            .flatMap { found in
                Value(primitive: found.primitive).flatMap { tweak.normalize($0) == $0 ? (value: $0, sourceName: found.sourceName) : nil }
            }
        let sourceValue = sourced?.value
        let sourceName = sourced?.sourceName
        if let value = override.flatMap(Value.init(primitive:)).map(tweak.normalize) {
            return TweakResolution(value: value, origin: .override, sourceValue: sourceValue, sourceName: sourceName)
        }
        if let sourceValue, let sourceName {
            return TweakResolution(value: sourceValue, origin: .source(sourceName), sourceValue: sourceValue, sourceName: sourceName)
        }
        return TweakResolution(value: tweak.defaultValue, origin: .default, sourceValue: nil, sourceName: nil)
    }

    /// A tweak with a `sourceKey` keeps an override that equals its default value, because the
    /// override hides the source value.
    func setValue<Value>(_ value: Value, for tweak: Tweak<Value>) {
        let value = tweak.normalize(value)
        let isRedundant = tweak.sourceKey == nil && value == tweak.defaultValue
        setOverride(isRedundant ? nil : value.primitive, id: tweak.id)
    }

    func reset(_ tweak: some AnyTweak) {
        setOverride(nil, id: tweak.id)
    }

    func publisher<Value>(for tweak: Tweak<Value>) -> AnyPublisher<Value, Never> {
        resolutionPublisher(for: tweak).map(\.value).removeDuplicates().eraseToAnyPublisher()
    }

    func resolutionPublisher<Value>(for tweak: Tweak<Value>) -> AnyPublisher<TweakResolution<Value>, Never> {
        changes
            .filter { $0 == nil || $0 == tweak.id }
            .map { _ in }
            .merge(with: Just(()))
            .map { [self] in resolution(for: tweak) }
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
