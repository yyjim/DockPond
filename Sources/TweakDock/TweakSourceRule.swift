import CryptoKit
import Foundation

/// Where a tweak reads its value when no override exists. Give it as `source:` in `@Tweak`.
///
/// ```swift
/// source: .remote("exp_paywall")                                          // TweakStore.remote, all devices
/// source: .remote("exp_ipad_sidebar", devices: [.pad])                    // iPad only
/// source: .local("lab_card_style", .variants(["A": 50, "B": 50]))         // a local split, no server
/// source: .local("rollout_new_badge", .rollout(0.1))                      // true on 10% of devices
/// ```
///
/// A launch argument `-tweak.<key> <value>` replaces the value in each case, for UI tests.
/// On a device that is not in `devices`, the tweak uses its default value.
public struct TweakSourceRule: Sendable {
    enum Kind: Sendable {
        case remote
        case local(TweakSplit)
    }

    public let key: String
    public let devices: TweakDevices
    let kind: Kind

    /// Reads `key` from `TweakStore.remote`, for example Firebase Remote Config.
    public static func remote(_ key: String, devices: TweakDevices = .all) -> TweakSourceRule {
        TweakSourceRule(key: key, devices: devices, kind: .remote)
    }

    /// Gives each device a value of `split`. The device keeps its value.
    public static func local(_ key: String, _ split: TweakSplit, devices: TweakDevices = .all) -> TweakSourceRule {
        TweakSourceRule(key: key, devices: devices, kind: .local(split))
    }
}

/// The values of a local split, and the part of the devices that gets each value.
public struct TweakSplit: Sendable {
    let weights: [(value: TweakPrimitive, weight: Double)]

    /// Gives variants in proportion to their weights. A variant is the raw value of an enum case, or the
    /// text of a number or a Boolean value. `["A": 1, "B": 1]` and `["A": 50, "B": 50]` are the same split.
    public static func variants(_ weights: KeyValuePairs<String, Double>) -> TweakSplit {
        TweakSplit(weights: weights.map { (TweakPrimitive.string($0.key), $0.value) })
    }

    /// Gives `true` to `fraction` of the devices. When you increase the fraction, the devices that had
    /// `true` keep it.
    public static func rollout(_ fraction: Double) -> TweakSplit {
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

/// The devices that a source rule applies to.
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
