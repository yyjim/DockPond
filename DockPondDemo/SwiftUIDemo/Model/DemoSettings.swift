import SwiftUI

@Observable
final class DemoSettings {
    var stateOverride = UserDefaults.standard.string(forKey: "HingeStateOverride").flatMap(HingeState.init(rawValue:))
    var axisOverride = UserDefaults.standard.string(forKey: "FoldAxisOverride").flatMap(FoldAxis.init(rawValue:))
    var showsFoldLine = true
    var itemStyle = ItemStyle()
    var selection: Item?
    var isShowingHistory = false
    private(set) var events: [HingeEvent] = []

    func record(_ reading: HingeReading) {
        guard events.first?.reading.state != reading.state else { return }
        events.insert(HingeEvent(date: .now, reading: reading), at: 0)
        if events.count > 30 {
            events.removeLast()
        }
    }
}

struct HingeEvent: Identifiable {
    let id = UUID()
    let date: Date
    let reading: HingeReading
}

@Observable
final class DuoDiagnostics {
    var hasHinge = false
}
