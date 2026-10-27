import SwiftUI

struct FoldLineOverlay: View {
    let axis: FoldAxis

    var body: some View {
        Canvas { context, size in
            var path = Path()
            switch axis {
            case .vertical:
                path.move(to: CGPoint(x: size.width / 2, y: 0))
                path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            case .horizontal:
                path.move(to: CGPoint(x: 0, y: size.height / 2))
                path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
            }
            context.stroke(path, with: .color(.red.opacity(0.7)), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
