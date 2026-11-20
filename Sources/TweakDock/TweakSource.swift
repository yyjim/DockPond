import Foundation

/// The experiment that gives a tweak its value when no override exists. Give it as `from:` in `@Tweak`.
///
/// ```swift
/// from: .experiment("exp_paywall")                       // all devices
/// from: .experiment("exp_ipad_sidebar", devices: [.pad])  // iPad only
/// ```
///
/// The tweak reads `key` from `TweakStore.experimentProvider`, for example Firebase Remote Config.
/// A launch argument `-tweak.<key> <value>` replaces the value, for UI tests.
/// On a device that is not in `devices`, the tweak uses its default value.
public struct TweakSource: Sendable {
    public let key: String
    public let devices: TweakDevices

    public static func experiment(_ key: String, devices: TweakDevices = .all) -> TweakSource {
        TweakSource(key: key, devices: devices)
    }
}

/// The devices that a `TweakSource` applies to.
public struct TweakDevices: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let standardPhone = TweakDevices(rawValue: 1 << 0)
    public static let foldablePhone = TweakDevices(rawValue: 1 << 5)
    public static let phone: TweakDevices = [.standardPhone, .foldablePhone]
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
        return device(forModel: info.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machineIdentifier())
        #endif
    }()

    /// From DeviceKit 5.10.0. Add each new foldable iPhone here.
    static let foldablePhoneModels: Set<String> = ["iPhone19,4"]

    static func device(forModel model: String) -> TweakDevices {
        if model.hasPrefix("iPad") { return .pad }
        if model.hasPrefix("RealityDevice") { return .vision }
        if foldablePhoneModels.contains(model) { return .foldablePhone }
        return .standardPhone
    }

    private static func machineIdentifier() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(bytes: $0.prefix { $0 != 0 }, encoding: .utf8) ?? "" }
    }
}
