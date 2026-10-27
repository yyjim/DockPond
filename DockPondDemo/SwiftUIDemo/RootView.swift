import SwiftUI

struct RootView: View {
    let settings: DemoSettings
    let diagnostics: DuoDiagnostics
    @State private var liveReading = HingeReading.unavailable
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        @Bindable var settings = settings
        GeometryReader { proxy in
            let context = makeContext(proxy)
            layout(for: context.posture)
                .environment(\.duoContext, context)
                .overlay {
                    if settings.showsFoldLine && context.hasFold {
                        FoldLineOverlay(axis: context.foldAxis)
                    }
                }
                .animation(.smooth, value: context.posture)
                .onChange(of: context.hasHinge, initial: true) { _, hasHinge in
                    diagnostics.hasHinge = hasHinge
                }
        }
        .ignoresSafeArea(.keyboard)
        .modifier(HingeObserver { reading in
            liveReading = reading
            settings.record(reading)
        })
        .sheet(isPresented: $settings.isShowingHistory) {
            HingeHistorySheet(settings: settings)
        }
    }

    private func makeContext(_ proxy: GeometryProxy) -> DuoContext {
        let insets = proxy.safeAreaInsets
        let windowSize = CGSize(
            width: proxy.size.width + insets.leading + insets.trailing,
            height: proxy.size.height + insets.top + insets.bottom
        )
        let hasHinge = liveReading.state != .unavailable
        let stateOverride = hasHinge ? settings.stateOverride : nil
        return DuoContext(
            hasHinge: hasHinge,
            reading: stateOverride.map { HingeReading(state: $0, angle: nil) } ?? liveReading,
            windowSize: windowSize,
            safeAreaInsets: insets,
            horizontalSizeClass: horizontalSizeClass,
            axisOverride: hasHinge ? settings.axisOverride : nil
        )
    }

    @ViewBuilder
    private func layout(for posture: Posture) -> some View {
        let selection = Bindable(settings).selection
        switch posture {
        case .outer, .compact:
            SingleColumnLayout(selection: selection)
        case .flat, .regular:
            SplitLayout(selection: selection)
        case .book:
            BookLayout(selection: selection)
        case .tabletop:
            TabletopLayout(selection: selection)
        }
    }
}

/// Reports hinge updates on iOS 27.1 and later. Earlier systems have no hinge API,
/// so the reading stays unavailable and the layout follows the size classes.
private struct HingeObserver: ViewModifier {
    let onChange: (HingeReading) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, newContext in
                onChange(HingeReading(newContext))
            }
        } else {
            content
        }
    }
}

#Preview {
    RootView(settings: DemoSettings(), diagnostics: DuoDiagnostics())
}
