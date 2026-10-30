import SwiftUI
import TweakDock

@MainActor
final class DemoModel: ObservableObject {
    @Published var title = ""
    @Published var fontSize: CGFloat = 0
    @Published var accent = DemoTweaks.Accent.blue
    @Published var cornerRadius: CGFloat = 0
    @Published var showsShadow = false
    @Published var badgeCount = 0
    @Published var isDarkMode = false
    @Published var environment = ""
    @Published var maxRetries = 0
    @Published var timeout = 0.0

    init() {
        DemoTweaks.titleTweak.publisher.assign(to: &$title)
        DemoTweaks.fontSizeTweak.publisher.assign(to: &$fontSize)
        DemoTweaks.accentTweak.publisher.assign(to: &$accent)
        DemoTweaks.cornerRadiusTweak.publisher.assign(to: &$cornerRadius)
        DemoTweaks.showsShadowTweak.publisher.assign(to: &$showsShadow)
        DemoTweaks.badgeCountTweak.publisher.assign(to: &$badgeCount)
        DemoTweaks.isDarkModeTweak.publisher.assign(to: &$isDarkMode)
        DemoTweaks.environmentTweak.publisher.assign(to: &$environment)
        DemoTweaks.maxRetriesTweak.publisher.assign(to: &$maxRetries)
        DemoTweaks.timeoutTweak.publisher.assign(to: &$timeout)
    }
}

struct DemoView: View {
    @StateObject private var model = DemoModel()
    @State private var showsTweaks = false
    @State private var cacheClearCount = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    card
                    values
                    Button("Open Tweaks") { showsTweaks = true }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("openTweaks")
                    Button("Open with TweaksWindow") { tweaksWindow?.presentTweaks() }
                        .accessibilityIdentifier("openTweaksWindow")
                    Text("You can also shake the device (⌃⌘Z in Simulator).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("TweakDock Demo")
        }
        .preferredColorScheme(model.isDarkMode ? .dark : .light)
        .sheet(isPresented: $showsTweaks) {
            TweaksView(DemoTweaks.allTweaks) { showsTweaks = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .demoCacheCleared)) { _ in
            cacheClearCount += 1
        }
    }

    private var card: some View {
        Text(model.title)
            .font(.system(size: model.fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 140)
            .background {
                RoundedRectangle(cornerRadius: model.cornerRadius)
                    .fill(accentColor)
                    .shadow(radius: model.showsShadow ? 12 : 0, y: model.showsShadow ? 6 : 0)
            }
            .overlay(alignment: .topTrailing) {
                if model.badgeCount > 0 {
                    Text("\(model.badgeCount)")
                        .font(.caption.bold())
                        .padding(8)
                        .background(.red, in: Circle())
                        .foregroundStyle(.white)
                        .offset(x: 8, y: -8)
                }
            }
            .accessibilityIdentifier("card")
    }

    private var values: some View {
        VStack(spacing: 8) {
            row("Title", model.title)
            row("Font Size", model.fontSize.formatted())
            row("Accent", model.accent.rawValue)
            row("Corner Radius", model.cornerRadius.formatted())
            row("Shows Shadow", "\(model.showsShadow)")
            row("Badge Count", "\(model.badgeCount)")
            row("Dark Mode", "\(model.isDarkMode)")
            row("Environment", model.environment)
            row("Max Retries", "\(model.maxRetries)")
            row("Timeout", model.timeout.formatted())
            row("Cache Cleared", "\(cacheClearCount)")
        }
        .padding()
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("value.\(name)")
        }
    }

    private var accentColor: Color {
        switch model.accent {
        case .blue: .blue
        case .orange: .orange
        case .purple: .purple
        case .green: .green
        }
    }

    private var tweaksWindow: TweaksWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow as? TweaksWindow }
            .first
    }
}
