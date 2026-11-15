import CryptoKit
import Foundation

/// Where a tweak reads its value when no override exists. Give it as `from:` in `@Tweak`.
///
/// ```swift
/// from: .experiment("exp_paywall")                                     // an A/B test in TweakStore.remote
/// from: .experiment("exp_ipad_sidebar", devices: [.pad])                // iPad only
/// from: .config("upload_limit")                                        // a plain value in TweakStore.remote
/// from: .localExperiment("lab_card_style", ["A": 50, "B": 50])          // an A/B test with no server
/// from: .rollout("new_badge", 0.1)                                     // true on 10% of devices
/// from: .custom("exp_server_paywall", serverProvider)                  // a value from your own provider
/// ```
///
/// A launch argument `-tweak.<key> <value>` replaces the value in each case, for UI tests.
/// On a device that is not in `devices`, the tweak uses its default value.
public struct TweakSource: Sendable {
    enum Kind: Sendable {
        case remote
        case local(TweakSplit)
        case custom(any TweakValueProvider)
    }

    public let key: String
    public let devices: TweakDevices
    /// `true` for `.experiment` and `.localExperiment`. `experimentProperties` lists these tweaks.
    public let isExperiment: Bool
    let kind: Kind

    /// An A/B test. Reads `key` from `TweakStore.remote`, for example Firebase Remote Config.
    public static func experiment(_ key: String, devices: TweakDevices = .all) -> TweakSource {
        TweakSource(key: key, devices: devices, isExperiment: true, kind: .remote)
    }

    /// A value that is not an experiment. Reads `key` from `TweakStore.remote`.
    public static func config(_ key: String, devices: TweakDevices = .all) -> TweakSource {
        TweakSource(key: key, devices: devices, isExperiment: false, kind: .remote)
    }

    /// An A/B test with no server. Gives each device a variant in proportion to the weights, and the device
    /// keeps it. A variant is the raw value of an enum case, or the text of a number or a Boolean value.
    /// `["A": 1, "B": 1]` and `["A": 50, "B": 50]` are the same split.
    public static func localExperiment(
        _ key: String, _ weights: KeyValuePairs<String, Double>, devices: TweakDevices = .all
    ) -> TweakSource {
        TweakSource(key: key, devices: devices, isExperiment: true, kind: .local(.weighted(weights)))
    }

    /// Gives `true` to `fraction` of the devices. When you increase the fraction, the devices that had
    /// `true` keep it.
    public static func rollout(_ key: String, _ fraction: Double, devices: TweakDevices = .all) -> TweakSource {
        TweakSource(key: key, devices: devices, isExperiment: false, kind: .local(.fraction(fraction)))
    }

    /// Reads `key` from your own provider, for example a second config service.
    public static func custom(_ key: String, _ provider: any TweakValueProvider, devices: TweakDevices = .all) -> TweakSource {
        TweakSource(key: key, devices: devices, isExperiment: false, kind: .custom(provider))
    }

    var provider: (any TweakValueProvider)? {
        if case let .custom(provider) = kind { provider } else { nil }
    }
}

/// The values of a local split, and the part of the devices that gets each value.
struct TweakSplit: Sendable {
    let weights: [(value: TweakPrimitive, weight: Double)]

    static func weighted(_ weights: KeyValuePairs<String, Double>) -> TweakSplit {
        TweakSplit(weights: weights.map { (TweakPrimitive.string($0.key), $0.value) })
    }

    static func fraction(_ fraction: Double) -> TweakSplit {
        let fraction = min(max(fraction, 0), 1)
        return TweakSplit(weights: [(.bool(true), fraction), (.bool(false), 1 - fraction)])
    }

    func value(at bucket: Double) -> TweakPrimitive? {
        let weights = weights.filter { $0.weight > 0 }
        let target = bucket * weights.reduce(0) { $0 + $1.weight }
        var total = 0.0
        for (value, weight) in weights {
            total += weight
            if target < total { return value }
        }
        return weights.last?.value
    }

    /// A number from 0 to 1 that does not change for a seed and a key.
    static func bucket(seed: String, key: String) -> Double {
        let digest = SHA256.hash(data: Data("\(seed).\(key)".utf8))
        let number = digest.prefix(8).reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
        return Double(number >> 11) / Double(UInt64(1) << 53)
    }
}

/// The devices that a `TweakSource` applies to.
public struct TweakDevices: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let phone = TweakDevices(rawValue: 1 << 0)
    public static let pad = TweakDevices(rawValue: 1 << 1)
    public static let mac = TweakDevices(rawValue: 1 << 2)
    public static let vision = TweakDevices(rawValue: 1 << 3)
    public static let tv = TweakDevices(rawValue: 1 << 4)
    public static let all: TweakDevices = [.phone, .pad, .mac, .vision, .tv]

    /// Uses the model identifier, because `UIDevice` can be read only on the main thread.
    /// An iPhone app that runs on an iPad is `.pad`.
    static let current: TweakDevices = {
        #if os(visionOS)
        return .vision
        #elseif os(macOS)
        return .mac
        #else
        let info = ProcessInfo.processInfo
        if info.isiOSAppOnMac || info.isMacCatalystApp { return .mac }
        let model = info.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machineIdentifier()
        if model.hasPrefix("iPad") { return .pad }
        if model.hasPrefix("AppleTV") { return .tv }
        if model.hasPrefix("RealityDevice") { return .vision }
        return .phone
        #endif
    }()

    private static func machineIdentifier() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
}
