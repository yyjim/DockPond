import UIKit

/// The Controls tool in the Dev Tools dock, built with UIKit. It selects the item
/// that the layouts show, and the panel stays open.
final class TestControlsView: UIView {
    var onPrevious: (() -> Void)?
    var onNext: (() -> Void)?

    private let itemLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        let title = UILabel()
        title.text = "Item"
        title.font = .preferredFont(forTextStyle: .caption1)
        title.textColor = .secondaryLabel
        itemLabel.font = .preferredFont(forTextStyle: .caption1)
        itemLabel.textAlignment = .center
        let previous = iconButton("chevron.left", label: "Previous") { [weak self] in self?.onPrevious?() }
        let next = iconButton("chevron.right", label: "Next") { [weak self] in self?.onNext?() }

        let stack = UIStackView(arrangedSubviews: [title, previous, itemLabel, next])
        stack.spacing = 10
        stack.alignment = .center
        itemLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showItem(_ swatch: Swatch) {
        itemLabel.text = swatch.name
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system, primaryAction: UIAction { _ in action() })
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.accessibilityLabel = label
        return button
    }
}
