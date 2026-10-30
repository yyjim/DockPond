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
    /// Use an app group to share tweaks with app extensions. Each process reads the file when it makes the store.
    public convenience init(name: String = "Tweaks", appGroup: String? = nil, isEnabled: Bool = true) {
        self.init(fileURL: Self.fileURL(name: name, appGroup: appGroup), isEnabled: isEnabled)
    }

    public init(fileURL: URL, isEnabled: Bool = true) {
        self.fileURL = fileURL
        enabled = isEnabled
        overrides = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode([String: TweakPrimitive].self, from: $0) } ?? [:]
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
        lock.withLock {
            overrides.removeAll()
            save()
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
            .prepend(())
            .map { [self] in value(for: tweak) }
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    private func setOverride(_ primitive: TweakPrimitive?, id: String) {
        let changed = lock.withLock {
            guard overrides[id] != primitive else { return false }
            overrides[id] = primitive
            save()
            return true
        }
        if changed {
            changes.send(id)
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
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
