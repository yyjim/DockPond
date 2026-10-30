/// Adds `static let allTweaks: [any AnyTweak]`, which lists each `@Tweak` member in declaration order,
/// and `static let tweakStore`, which keeps their values.
///
/// To share tweaks with app extensions, give a store in an app group container.
/// Declare the store one time, and use it in each `@Tweaks` type:
///
/// ```swift
/// extension TweakStore {
///     static let appGroup = TweakStore(appGroup: "group.com.example.app")
/// }
///
/// @Tweaks(store: .appGroup)
/// enum AppTweaks { ... }
/// ```
@attached(member, names: named(allTweaks), named(tweakStore))
public macro Tweaks(store: TweakStore = .shared) = #externalMacro(module: "TweakDockMacros", type: "TweaksMacro")

/// Makes a static property read and write a tweak value.
///
/// It also adds a `<name>Tweak` peer, which gives the publisher, the default value, and `reset()`.
/// Use it in a type that has the `@Tweaks` attribute.
///
/// ```swift
/// @Tweak(collection: "UI", group: "Theme", name: "Dark Mode", defaultValue: true)
/// static var isDarkMode: Bool
/// ```
@attached(accessor)
@attached(peer, names: suffixed(Tweak))
public macro Tweak<T>(collection: String, group: String, name: String, defaultValue: T)
    = #externalMacro(module: "TweakDockMacros", type: "TweakMacro")

@attached(accessor)
@attached(peer, names: suffixed(Tweak))
public macro Tweak<T>(collection: String, group: String, name: String, min: T, max: T, defaultValue: T)
    = #externalMacro(module: "TweakDockMacros", type: "TweakMacro")

@attached(accessor)
@attached(peer, names: suffixed(Tweak))
public macro Tweak<T>(collection: String, group: String, name: String, options: [T], defaultValue: T)
    = #externalMacro(module: "TweakDockMacros", type: "TweakMacro")

/// Makes a static method an action tweak, which the tweaks UI runs when you tap it.
@attached(peer, names: suffixed(Tweak))
public macro Tweak(collection: String, group: String, name: String)
    = #externalMacro(module: "TweakDockMacros", type: "TweakMacro")
