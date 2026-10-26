import SwiftUI

/// The last 30 hinge state changes from iOS. A forced hinge state does not add rows.
struct HingeHistorySheet: View {
    let settings: DemoSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if settings.events.isEmpty {
                    Text("No hinge updates yet. Fold or open the device.")
                        .foregroundStyle(.secondary)
                }
                ForEach(settings.events) { event in
                    HStack {
                        Text(event.reading.state.rawValue)
                        if let angle = event.reading.angle {
                            Text("\(Int(angle.degrees.rounded()))°")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(event.date, format: .dateTime.hour().minute().second())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Hinge History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
