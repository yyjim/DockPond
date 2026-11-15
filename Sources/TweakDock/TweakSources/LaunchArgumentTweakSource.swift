import Foundation

/// Reads values from launch arguments, such as `-tweak.exp_paywall B`. Use it to set values in UI tests.
public final class LaunchArgumentTweakSource: TweakSource {
    public let name: String
    private let values: [String: String]

    public init(name: String = "Launch Argument", prefix: String = "-tweak.", arguments: [String] = ProcessInfo.processInfo.arguments) {
        self.name = name
        var values: [String: String] = [:]
        for (argument, value) in zip(arguments, arguments.dropFirst())
            where argument.hasPrefix(prefix) && !value.hasPrefix(prefix) {
            values[String(argument.dropFirst(prefix.count))] = value
        }
        self.values = values
    }

    public func primitive(forKey key: String, as kind: TweakPrimitive.Kind) -> TweakPrimitive? {
        values[key].flatMap { TweakPrimitive(string: $0, as: kind) }
    }
}
