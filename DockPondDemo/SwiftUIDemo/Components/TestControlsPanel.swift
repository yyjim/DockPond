import SwiftUI

struct TestControlsPanel: View {
    let settings: DemoSettings

    private var item: Item { settings.selection ?? Item.samples[0] }

    var body: some View {
        HStack {
            Text("Item")
                .foregroundStyle(Color(uiColor: .secondaryLabel))
            Button("Previous", systemImage: "chevron.left") { settings.selection = item.previous }
            Text(item.title)
                .frame(maxWidth: .infinity)
            Button("Next", systemImage: "chevron.right") { settings.selection = item.next }
        }
        .labelStyle(.iconOnly)
        .controlSize(.small)
        .font(.caption)
    }
}
