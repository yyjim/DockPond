# tweakdock

`tweakdock` writes TweakDock experiments from a YAML file.
Each experiment in the file becomes a variant enum and a `@Tweak` property.

## Install

Add the gem to the `Gemfile` of the app. Use the tag of the DockPond version that the app uses.

```ruby
gem "tweakdock", git: "https://github.com/yyjim/DockPond", tag: "0.6.0", glob: "gems/tweakdock/*.gemspec"
```

Then run `bundle install`.

## Write the experiments

```yaml
# Experiments.yml
output: Experiments.swift   # The Swift file to write, relative to this file.
store: .experiments         # The store of @Tweaks. Default: .shared.

experiments:
  exp_paywall: [A, B, C]    # The first variant is the default.

  exp_ipad_sidebar:
    variants: [control, sidebar]
    default: sidebar
    devices: [pad, mac]

  lab_storage_upsell:
    variants: ["off", "on"]
    group: Lab
```

Each key of `experiments` is the key in the A/B test service, for example in Firebase Remote Config.
The generator makes the Swift names from the key: `exp_ipad_sidebar` gives the type `ExpIpadSidebar` and the property `expIpadSidebar`.

### Settings

| Setting | Default | Description |
| --- | --- | --- |
| `output` | (necessary) | The Swift file, relative to the YAML file. |
| `type` | `Experiments` | The name of the `@Tweaks` enum. |
| `store` | `.shared` | The `TweakStore` of `@Tweaks`. |
| `collection` | `Experiments` | The collection in the tweaks UI. |
| `group` | `A/B Tests` | The group in the tweaks UI. An experiment can set its own `group`. |
| `access` | internal | Set `public` to make the declarations public. |

### Experiment settings

| Setting | Default | Description |
| --- | --- | --- |
| `variants` | (necessary) | The variants. Each variant must be a Swift name. |
| `default` | The first variant | The value when the service gives no valid value. |
| `devices` | `all` | `all`, or a list of `phone`, `pad`, `mac`, `vision`, and `tv`. |
| `group` | The file `group` | The group in the tweaks UI. |

Put quotes around `on`, `off`, `yes`, and `no`. Without quotes, YAML reads them as `true` and `false`.

## Generate the Swift file

```sh
bundle exec tweakdock generate Experiments.yml   # Writes the Swift file.
bundle exec tweakdock check Experiments.yml      # Fails when the Swift file is not up to date.
```

`generate` does not change a file that is up to date. `check` changes no files, so you can run it in CI.
Both commands accept more than one YAML file.

Do not edit the Swift file. Do not format or lint it, because `check` compares it with the generated code.

The generated code for `exp_paywall`:

```swift
@Tweaks(store: .experiments)
enum Experiments {
    enum ExpPaywall: String, CaseIterable, TweakValue {
        case A, B, C
    }

    @Tweak(
        collection: "Experiments",
        group: "A/B Tests",
        name: "exp_paywall",
        defaultValue: ExpPaywall.A,
        from: .experiment("exp_paywall")
    )
    static var expPaywall: ExpPaywall
}
```

## Test the gem

```sh
cd gems/tweakdock
rake
```

The tests also check that `Tests/TweakDockTests/GeneratedExperiments.swift` is up to date.
The TweakDock tests compile that file and read its values.
