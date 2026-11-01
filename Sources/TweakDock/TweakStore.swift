import Combine
import Foundation

/// Keeps the values that override tweak defaults, and saves them to a JSON file.
public final class TweakStore: @unchecked Sendable {
    public static let shared = TweakStore()

    public let fileURL: URL
    private let lock = NSLock()
    private var overrides: [String: TweakPrimitive]
    private var enabled: Bool
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

    /// When `false`, each tweak returns its default value. Set it to `false` in release builds.
    public var isEnabled: Bool {
        get { lock.withLock { enabled } }
        set {
            lock.withLock { enabled = newValue }
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
        let primitive = lock.withLock { enabled ? overrides[tweak.id] : nil }
        return primitive.flatMap(Value.init(primitive:)).map(tweak.normalize) ?? tweak.defaultValue
    }

    func setValue<Value>(_ value: Value, for tweak: Tweak<Value>) {
        let value = tweak.normalize(value)
        setOverride(value == tweak.defaultValue ? nil : value.primitive, id: tweak.id)
    }

    func reset(_ tweak: some AnyTweak) {
        setOverride(nil, id: tweak.id)
    }

    func publisher<Value>(for tweak: Tweak<Value>) -> AnyPublisher<Value, Never> {
        changes
            .filter { $0 == nil || $0 == tweak.id }
            .map { _ in }
            .merge(with: Just(()))
            .map { [self] in value(for: tweak) }
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

    /// `lock` guards only this instance. Another process, or another store of the same
    /// file, can save between a read and a write, so an advisory file lock guards the
    /// whole change. `lock` is not held while this waits, so reads do not wait for
    /// another process.
    private func withFileLock<T>(_ body: () -> T) -> T {
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let descriptor = open(fileURL.path + ".lock", O_CREAT | O_RDWR, 0o644)
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
