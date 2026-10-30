import SwiftUI

/// Lists tweaks by collection and group, and lets you edit them. The layout follows SwiftTweaks.
public struct TweaksView: View {
    private let tweaks: [any AnyTweak]
    private let onDismiss: (() -> Void)?
    @State private var confirmsReset = false

    public init(_ tweaks: [any AnyTweak], onDismiss: (() -> Void)? = nil) {
        self.tweaks = tweaks
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            List(tweaks.ordered(by: \.collection), id: \.key) { collection in
                NavigationLink(collection.key) {
                    TweakCollectionView(title: collection.key, tweaks: collection.values)
                }
            }
            .groupedListStyle()
            .navigationTitle("Tweaks")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Reset All") { confirmsReset = true }
                }
            }
            .confirmationDialog("Reset all tweaks to their default values?", isPresented: $confirmsReset, titleVisibility: .visible) {
                Button("Reset All Tweaks", role: .destructive) {
                    tweaks.forEach { ($0 as? any PrimitiveTweak)?.reset() }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let onDismiss {
                DoneBar(onDismiss: onDismiss)
            }
        }
    }
}

private struct TweakCollectionView: View {
    let title: String
    let tweaks: [any AnyTweak]

    var body: some View {
        List {
            ForEach(tweaks.ordered(by: \.group), id: \.key) { group in
                Section(group.key) {
                    ForEach(group.values, id: \.id) { tweak in
                        if let tweak = tweak as? TweakAction {
                            Button(tweak.name) { tweak() }
                        } else if let tweak = tweak as? any PrimitiveTweak {
                            TweakRow(tweak: tweak)
                        }
                    }
                }
            }
        }
        .groupedListStyle()
        .navigationTitle(title)
        .inlineNavigationTitle()
    }
}

private struct TweakRow: View {
    let tweak: any PrimitiveTweak
    @State private var value: TweakPrimitive

    init(tweak: any PrimitiveTweak) {
        self.tweak = tweak
        _value = State(initialValue: tweak.primitiveValue)
    }

    var body: some View {
        content.onReceive(tweak.primitivePublisher) { value = $0 }
    }

    @ViewBuilder private var content: some View {
        switch (tweak.control, value) {
        case (.toggle, .bool):
            Toggle(tweak.name, isOn: binding(Bool.self))
        case let (.number(range), .int), let (.number(range), .double):
            numberRow(range: range)
        case (.text, .string):
            HStack {
                Text(tweak.name)
                TextField(tweak.name, text: binding(String.self))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }
        case let (.picker(options), .string(current)):
            NavigationLink {
                OptionsView(tweak: tweak, options: options)
            } label: {
                LabeledContent(tweak.name, value: current)
            }
        default:
            LabeledContent(tweak.name, value: "Unsupported")
        }
    }

    private func numberRow(range: ClosedRange<Double>?) -> some View {
        let number = Binding(
            get: { value.doubleValue ?? 0 },
            set: { update(isInteger ? .int(Int($0.rounded())) : .double($0)) }
        )
        let step = stepSize(range: range)
        return HStack {
            Text(tweak.name)
            Spacer()
            TextField(tweak.name, value: number, format: .number.precision(.fractionLength(0 ... 3)))
                .multilineTextAlignment(.trailing)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 80)
                .numberKeyboard(isInteger: isInteger)
            if let range {
                Stepper(tweak.name, value: number, in: range, step: step).labelsHidden()
            } else {
                Stepper(tweak.name, value: number, step: step).labelsHidden()
            }
        }
    }

    private var isInteger: Bool {
        if case .int = tweak.defaultPrimitive { true } else { false }
    }

    /// Uses the SwiftTweaks rule: 0.01 for fractions between 0 and 1, else 1.
    private func stepSize(range: ClosedRange<Double>?) -> Double {
        let defaultValue = tweak.defaultPrimitive.doubleValue ?? 0
        let isSmall = (0 ..< 1).contains(defaultValue) && (range?.upperBound ?? 0) <= 1
        return !isInteger && isSmall ? 0.01 : 1
    }

    private func binding<Value: TweakValue>(_: Value.Type) -> Binding<Value> {
        Binding(
            get: { Value(primitive: value) ?? Value(primitive: tweak.defaultPrimitive)! },
            set: { update($0.primitive) }
        )
    }

    private func update(_ primitive: TweakPrimitive) {
        value = primitive
        tweak.primitiveValue = primitive
    }
}

private struct OptionsView: View {
    let tweak: any PrimitiveTweak
    let options: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(options, id: \.self) { option in
            Button {
                tweak.primitiveValue = .string(option)
                dismiss()
            } label: {
                HStack {
                    Text(option).foregroundStyle(Color.primary)
                    Spacer()
                    if tweak.primitiveValue == .string(option) {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
        .groupedListStyle()
        .navigationTitle(tweak.name)
        .inlineNavigationTitle()
    }
}

/// A SwiftUI bar, because a `.bottomBar` toolbar inside a `UIHostingController` adds an unsupported UIKit subview.
private struct DoneBar: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button("Done", action: onDismiss).bold()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }
}

private extension View {
    @ViewBuilder func groupedListStyle() -> some View {
        #if os(iOS)
        listStyle(.grouped)
        #else
        self
        #endif
    }

    @ViewBuilder func inlineNavigationTitle() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder func numberKeyboard(isInteger: Bool) -> some View {
        #if os(iOS)
        keyboardType(isInteger ? .numberPad : .decimalPad)
        #else
        self
        #endif
    }
}

private extension Array where Element == any AnyTweak {
    /// Groups the tweaks by a key, and keeps the declaration order.
    func ordered(by key: (any AnyTweak) -> String) -> [(key: String, values: [any AnyTweak])] {
        var groups: [(key: String, values: [any AnyTweak])] = []
        for tweak in self {
            if let index = groups.firstIndex(where: { $0.key == key(tweak) }) {
                groups[index].values.append(tweak)
            } else {
                groups.append((key(tweak), [tweak]))
            }
        }
        return groups
    }
}
