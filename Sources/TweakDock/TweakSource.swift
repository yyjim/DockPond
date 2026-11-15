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
        case custom(any TweakValueProvider)
        /// A local split. Each weight is more than 0.
        case split([(value: TweakPrimitive, weight: Double)])
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
        let weights = weights.map { (value: TweakPrimitive.string($0.key), weight: $0.value) }
        return TweakSource(key: key, devices: devices, isExperiment: true, kind: .split(weights.filter { $0.weight > 0 }))
    }

    /// Gives `true` to `fraction` of the devices. When you increase the fraction, the devices that had
    /// `true` keep it.
    public static func rollout(_ key: String, _ fraction: Double, devices: TweakDevices = .all) -> TweakSource {
        let fraction = min(max(fraction, 0), 1)
        let weights: [(value: TweakPrimitive, weight: Double)] = [(.bool(true), fraction), (.bool(false), 1 - fraction)]
        return TweakSource(key: key, devices: devices, isExperiment: false, kind: .split(weights.filter { $0.weight > 0 }))
    }

    /// Reads `key` from your own provider, for example a second config service.
    public static func custom(_ key: String, _ provider: any TweakValueProvider, devices: TweakDevices = .all) -> TweakSource {
        TweakSource(key: key, devices: devices, isExperiment: false, kind: .custom(provider))
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
        #elseif os(tvOS)
        return .tv
        #else
        let info = ProcessInfo.processInfo
        if info.isiOSAppOnMac || info.isMacCatalystApp { return .mac }
        let model = info.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machineIdentifier()
        if model.hasPrefix("iPad") { return .pad }
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
