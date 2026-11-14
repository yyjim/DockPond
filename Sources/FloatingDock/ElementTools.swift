import SwiftUI
import UIKit

@MainActor
extension DockTool {
    /// The title and icon of the tool that holds all element tools of a dock.
    public static let elementsTitle = "General"
    static let elementsID = "elements"

    enum Element {
        case labeled(String, AnyView)
        case wide(AnyView)
    }

    init(element: Element, title: String, id: String?) {
        self.id = id ?? title
        self.title = title
        self.systemImage = "slider.horizontal.3"
        self.element = element
        self.content = AnyView(ElementRows(elements: [element]))
        self.actions = AnyView(EmptyView())
    }

    /// Moves all element tools into one "General" tool, at the place of the first one.
    static func groupingElements(_ tools: [DockTool]) -> [DockTool] {
        let elements = tools.compactMap(\.element)
        guard let first = tools.firstIndex(where: { $0.element != nil }) else { return tools }
        var grouped = tools.filter { $0.element == nil }
        grouped.insert(
            DockTool(elementsTitle, systemImage: "slider.horizontal.3", id: elementsID) {
                ElementRows(elements: elements)
            },
            at: first
        )
        return grouped
    }

    // MARK: SwiftUI

    /// A switch that changes a Boolean value of the app. `tint` sets the color of
    /// the switch. If it is `nil`, the switch uses the panel tint. `alignment` sets
    /// the position of the switch in its row.
    public static func toggle(
        _ title: String,
        isOn: Binding<Bool>,
        tint: Color? = nil,
        alignment: HorizontalAlignment = .trailing,
        id: String? = nil
    ) -> DockTool {
        let view = AnyView(
            ElementToggle(title: title, isOn: isOn, tint: tint, alignment: alignment)
        )
        return DockTool(element: .labeled(title, view), title: title, id: id)
    }

    /// A control that selects one value of the app. Four options or fewer show as
    /// segments, more show as a menu.
    public static func selector<Value: Hashable>(
        _ title: String,
        selection: Binding<Value>,
        options: KeyValuePairs<String, Value>,
        id: String? = nil
    ) -> DockTool {
        let view = AnyView(
            SelectorControl(title: title, selection: selection, options: Array(options))
        )
        return DockTool(element: .labeled(title, view), title: title, id: id)
    }

    /// A stepper that changes an integer value of the app.
    public static func stepper(
        _ title: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        step: Int = 1,
        id: String? = nil
    ) -> DockTool {
        let view = AnyView(
            Stepper(value: value, in: range, step: step) {
                Text(value.wrappedValue, format: .number)
                    .monospacedDigit()
            }
            .accessibilityLabel(title)
        )
        return DockTool(element: .labeled(title, view), title: title, id: id)
    }

    /// A slider that changes a decimal value of the app.
    public static func slider(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0...2)),
        id: String? = nil
    ) -> DockTool {
        let view = AnyView(
            HStack {
                Slider(value: value, in: range)
                    .accessibilityLabel(title)
                Text(value.wrappedValue, format: format)
                    .monospacedDigit()
                    .frame(minWidth: 36, alignment: .trailing)
            }
        )
        return DockTool(element: .labeled(title, view), title: title, id: id)
    }

    /// A button that runs an action of the app. The panel stays open.
    public static func button(
        _ title: String,
        systemImage: String? = nil,
        role: ButtonRole? = nil,
        id: String? = nil,
        action: @escaping @MainActor () -> Void
    ) -> DockTool {
        let view = AnyView(
            ElementButton(title: title, systemImage: systemImage, role: role, action: action)
        )
        return DockTool(element: .wide(view), title: title, id: id)
    }

    // MARK: UIKit

    /// A switch that reads and writes a Boolean value of the app through closures.
    /// `tint` sets the color of the switch. If it is `nil`, the switch uses the
    /// panel tint. `alignment` sets the position of the switch in its row.
    public static func toggle(
        _ title: String,
        tint: Color? = nil,
        alignment: HorizontalAlignment = .trailing,
        id: String? = nil,
        get: @escaping @MainActor () -> Bool,
        set: @escaping @MainActor (Bool) -> Void
    ) -> DockTool {
        let view = AnyView(
            ClosureBound(get: get, set: set) { ElementToggle(title: title, isOn: $0, tint: tint, alignment: alignment) }
        )
        return DockTool(element: .labeled(title, view), title: title, id: id)
    }

    /// A control that selects one of the option titles. The closures read and
    /// write the index of the selected option.
    public static func selector(
        _ title: String,
        options: [String],
        id: String? = nil,
        get: @escaping @MainActor () -> Int,
        set: @escaping @MainActor (Int) -> Void
    ) -> DockTool {
        let view = AnyView(
            ClosureBound(get: get, set: set) { selection in
                SelectorControl(
                    title: title,
                    selection: selection,
                    options: options.enumerated().map { ($0.element, $0.offset) }
                )
            }
        )
        return DockTool(element: .labeled(title, view), title: title, id: id)
    }

    public static func stepper(
        _ title: String,
        in range: ClosedRange<Int>,
        step: Int = 1,
        id: String? = nil,
        get: @escaping @MainActor () -> Int,
        set: @escaping @MainActor (Int) -> Void
    ) -> DockTool {
        let view = AnyView(
            ClosureBound(get: get, set: set) { value in
                Stepper(value: value, in: range, step: step) {
                    Text(value.wrappedValue, format: .number)
                        .monospacedDigit()
                }
                .accessibilityLabel(title)
            }
        )
        return DockTool(element: .labeled(title, view), title: title, id: id)
    }

    public static func slider(
        _ title: String,
        in range: ClosedRange<Double>,
        format: FloatingPointFormatStyle<Double> = .number.precision(.fractionLength(0...2)),
        id: String? = nil,
        get: @escaping @MainActor () -> Double,
        set: @escaping @MainActor (Double) -> Void
    ) -> DockTool {
        let view = AnyView(
            ClosureBound(get: get, set: set) { value in
                HStack {
                    Slider(value: value, in: range)
                        .accessibilityLabel(title)
                    Text(value.wrappedValue, format: format)
                        .monospacedDigit()
                        .frame(minWidth: 36, alignment: .trailing)
                }
            }
        )
        return DockTool(element: .labeled(title, view), title: title, id: id)
    }
}

struct ElementRows: View {
    let elements: [DockTool.Element]
    @State private var revision = 0
    @Environment(\.dockPresentationCount) private var presentationCount

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
            ForEach(elements.indices, id: \.self) { index in
                switch elements[index] {
                case let .labeled(title, control):
                    GridRow {
                        Text(title)
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                        control
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                case let .wide(view):
                    view
                        .gridCellColumns(2)
                }
            }
        }
        .controlSize(.small)
        .font(.caption)
        .environment(\.elementRevision, revision &+ presentationCount)
        .environment(\.elementDidChange, ElementChange { revision += 1 })
    }
}

/// Closure-backed values do not notify SwiftUI, so every element reads its value
/// again after any element changes the app, and each time the panel opens.
struct ElementChange {
    let action: @MainActor () -> Void
}

extension EnvironmentValues {
    @Entry var elementRevision = 0
    @Entry var dockPresentationCount = 0
    @Entry var elementDidChange = ElementChange {}
}

private struct ElementToggle: View {
    let title: String
    @Binding var isOn: Bool
    let tint: Color?
    let alignment: HorizontalAlignment

    var body: some View {
        Toggle(title, isOn: $isOn)
            .labelsHidden()
            .tint(ifSet: tint)
            .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
    }
}

private struct SelectorControl<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [(String, Value)]

    var body: some View {
        let picker = Picker(title, selection: $selection) {
            ForEach(options.indices, id: \.self) { index in
                Text(options[index].0).tag(options[index].1)
            }
        }
        if options.count <= 4 {
            picker.pickerStyle(.segmented)
        } else {
            picker.pickerStyle(.menu)
        }
    }
}

private struct ElementButton: View {
    let title: String
    let systemImage: String?
    let role: ButtonRole?
    let action: @MainActor () -> Void
    @Environment(\.elementDidChange) private var didChange

    var body: some View {
        Button(role: role) {
            action()
            didChange.action()
        } label: {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
        }
        .buttonStyle(.bordered)
        .frame(maxWidth: .infinity)
    }
}

private struct ClosureBound<Value, Control: View>: View {
    let get: @MainActor () -> Value
    let set: @MainActor (Value) -> Void
    @ViewBuilder let control: (Binding<Value>) -> Control
    @Environment(\.elementRevision) private var revision
    @Environment(\.elementDidChange) private var didChange

    var body: some View {
        let _ = revision
        control(Binding(
            get: { get() },
            set: { newValue in
                set(newValue)
                didChange.action()
            }
        ))
    }
}
