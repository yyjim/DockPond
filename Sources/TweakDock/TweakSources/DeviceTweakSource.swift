#if canImport(UIKit)
import Combine
import UIKit

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
        namedValue(forKey: key, as: kind) { $0 }?.value
    }

    func namedValue<T>(
        forKey key: String, as kind: TweakPrimitive.Kind, transform: (TweakPrimitive) -> T?
    ) -> (value: T, sourceName: String)? {
        guard devices[key].map({ $0.contains(idiom) }) ?? true else { return nil }
        return base.lookup(key, as: kind, transform: transform)
    }

    public var changes: AnyPublisher<Void, Never> { base.changes }
}
#endif
