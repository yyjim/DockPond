@testable import FloatingDock
import Testing
import UIKit

@MainActor
struct HostedContentViewTests {
    @Test func wrapsMultilineTextToTheProposedWidth() {
        let label = UILabel()
        label.numberOfLines = 0
        label.text = String(repeating: "A long line of help text that must wrap. ", count: 8)
        let view = pinned(label)
        let oneLine = label.intrinsicContentSize

        let size = HostedContentView.fittingSize(of: view, width: 300)

        #expect(size.width == 300)
        #expect(size.height > oneLine.height * 2)
    }

    @Test func keepsTheMinimumWidthOfFixedContent() {
        let fixed = UIView()
        fixed.widthAnchor.constraint(equalToConstant: 90).isActive = true
        fixed.heightAnchor.constraint(equalToConstant: 20).isActive = true
        let view = pinned(fixed)

        let size = HostedContentView.fittingSize(of: view, width: 0)

        #expect(size.width == 90)
        #expect(size.height == 20)
    }

    private func pinned(_ content: UIView) -> UIView {
        let container = UIView()
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: container.topAnchor),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }
}
