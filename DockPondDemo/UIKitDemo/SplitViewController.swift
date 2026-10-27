import UIKit

/// A list and a detail page. The split view collapses to one column in compact
/// width, and shows both columns when the window is wide, such as a flat iPhone Duo.
final class SplitViewController: UISplitViewController {
    private let list = ColorListViewController()
    private let detail = ColorDetailViewController()

    init(selection: Swatch, onSelect: @escaping (Swatch) -> Void) {
        super.init(style: .doubleColumn)
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        setViewController(UINavigationController(rootViewController: list), for: .primary)
        setViewController(UINavigationController(rootViewController: detail), for: .secondary)
        delegate = self
        detail.swatch = selection
        list.onSelect = { [weak self] swatch in
            onSelect(swatch)
            self?.show(.secondary)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(_ swatch: Swatch) {
        detail.swatch = swatch
    }
}

extension SplitViewController: UISplitViewControllerDelegate {
    func splitViewController(
        _ svc: UISplitViewController,
        topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column
    ) -> UISplitViewController.Column {
        .primary
    }
}

final class ColorListViewController: UITableViewController {
    var onSelect: ((Swatch) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Colors"
        navigationController?.navigationBar.prefersLargeTitles = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        NotificationCenter.default.addObserver(self, selector: #selector(swatchStyleDidChange), name: SwatchStyle.didChange, object: nil)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        Swatch.all.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let swatch = Swatch.all[indexPath.row]
        let style = SwatchStyle.current
        var content = cell.defaultContentConfiguration()
        content.text = swatch.name
        content.secondaryText = style.showsSummaries ? swatch.summary : nil
        content.secondaryTextProperties.numberOfLines = style.summaryLines
        content.image = UIImage(systemName: "circle.fill")
        content.imageProperties.tintColor = style.color(for: swatch)
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    @objc private func swatchStyleDidChange() {
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        onSelect?(Swatch.all[indexPath.row])
    }
}

final class ColorDetailViewController: UIViewController {
    var swatch = Swatch.all[7] {
        didSet { render() }
    }

    private let colorView = UIView()
    private let nameLabel = UILabel()
    private let articleLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        colorView.layer.cornerCurve = .continuous
        NotificationCenter.default.addObserver(self, selector: #selector(swatchStyleDidChange), name: SwatchStyle.didChange, object: nil)
        nameLabel.font = .preferredFont(forTextStyle: .largeTitle)
        articleLabel.font = .preferredFont(forTextStyle: .body)
        articleLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [colorView, nameLabel, articleLabel])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            colorView.heightAnchor.constraint(equalTo: colorView.widthAnchor, multiplier: 0.6),
        ])
        render()
    }

    @objc private func swatchStyleDidChange() {
        render()
    }

    private func render() {
        guard isViewLoaded else { return }
        title = swatch.name
        let style = SwatchStyle.current
        colorView.layer.cornerRadius = 24 * style.cornerScale
        colorView.backgroundColor = style.color(for: swatch)
        nameLabel.text = swatch.name
        articleLabel.text = swatch.article
    }
}
