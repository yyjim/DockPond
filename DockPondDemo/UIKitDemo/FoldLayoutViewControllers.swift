import UIKit

private let foldGutter: CGFloat = 28
private let pageMargin: CGFloat = 16

/// Half open with a vertical fold: a two-page spread split exactly at the fold.
/// The view fills the window, so the fold is at the middle of its bounds.
final class BookViewController: UIViewController {
    var swatch: Swatch {
        didSet { render() }
    }

    private let onSelect: (Swatch) -> Void
    private let leftPage = UIView()
    private let rightPage = UIView()
    private let picture = UIView()
    private let leftCaption = UILabel()
    private let rightCaption = UILabel()
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let articleLabel = UILabel()

    init(swatch: Swatch, onSelect: @escaping (Swatch) -> Void) {
        self.swatch = swatch
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground

        picture.layer.cornerCurve = .continuous
        NotificationCenter.default.addObserver(self, selector: #selector(swatchStyleDidChange), name: SwatchStyle.didChange, object: nil)
        picture.setContentHuggingPriority(.defaultLow, for: .vertical)
        for caption in [leftCaption, rightCaption] {
            caption.font = .preferredFont(forTextStyle: .caption1)
            caption.textColor = .secondaryLabel
            caption.textAlignment = .center
        }
        let previous = pageButton("Previous", symbol: "chevron.left") { [weak self] in
            guard let self else { return }
            onSelect(swatch.previous)
        }
        configurePage(leftPage, with: [picture, leftCaption, previous])

        titleLabel.font = .preferredFont(forTextStyle: .largeTitle)
        summaryLabel.font = .preferredFont(forTextStyle: .title3)
        summaryLabel.numberOfLines = 0
        articleLabel.font = .preferredFont(forTextStyle: .body)
        articleLabel.numberOfLines = 0
        let textStack = UIStackView(arrangedSubviews: [titleLabel, summaryLabel, articleLabel])
        textStack.axis = .vertical
        textStack.spacing = 12
        let scrollView = UIScrollView()
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)
        textStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(textStack)
        NSLayoutConstraint.activate([
            textStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            textStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            textStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor),
            textStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor),
        ])
        let next = pageButton("Next", symbol: "chevron.right") { [weak self] in
            guard let self else { return }
            onSelect(swatch.next)
        }
        configurePage(rightPage, with: [scrollView, rightCaption, next])
        render()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let area = view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: pageMargin, dy: pageMargin)
        let foldX = view.bounds.midX
        leftPage.frame = CGRect(x: area.minX, y: area.minY, width: max(0, foldX - foldGutter / 2 - area.minX), height: area.height)
        rightPage.frame = CGRect(x: foldX + foldGutter / 2, y: area.minY, width: max(0, area.maxX - foldX - foldGutter / 2), height: area.height)
    }

    private func configurePage(_ page: UIView, with views: [UIView]) {
        page.backgroundColor = .systemBackground
        page.layer.cornerRadius = 12
        let stack = UIStackView(arrangedSubviews: views)
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        page.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: page.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: page.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: page.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: page.trailingAnchor, constant: -16),
        ])
        view.addSubview(page)
    }

    @objc private func swatchStyleDidChange() {
        render()
    }

    private func render() {
        guard isViewLoaded else { return }
        let style = SwatchStyle.current
        picture.layer.cornerRadius = 24 * style.cornerScale
        UIView.animate(withDuration: 0.25) { self.picture.backgroundColor = style.color(for: self.swatch) }
        leftCaption.text = "Page \(swatch.index * 2 + 1)"
        rightCaption.text = "Page \(swatch.index * 2 + 2)"
        titleLabel.text = swatch.name
        summaryLabel.text = swatch.summary
        summaryLabel.textColor = swatch.color
        articleLabel.text = swatch.article
    }
}

/// Half open with a horizontal fold: a viewer on the upper half and controls on
/// the lower half, split exactly at the fold.
final class TabletopViewController: UIViewController {
    var swatch: Swatch {
        didSet { render() }
    }

    private let onSelect: (Swatch) -> Void
    private let viewer = UIView()
    private let viewerLabel = UILabel()
    private let controls = UIView()
    private let progress = UIProgressView(progressViewStyle: .default)
    private let playButton = UIButton(type: .system)
    private var thumbnails: [UIButton] = []
    private var isPlaying = false

    init(swatch: Swatch, onSelect: @escaping (Swatch) -> Void) {
        self.swatch = swatch
        self.onSelect = onSelect
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        overrideUserInterfaceStyle = .dark

        viewer.layer.cornerCurve = .continuous
        NotificationCenter.default.addObserver(self, selector: #selector(swatchStyleDidChange), name: SwatchStyle.didChange, object: nil)
        viewerLabel.font = .systemFont(ofSize: 34, weight: .bold)
        viewerLabel.textColor = .white
        viewerLabel.translatesAutoresizingMaskIntoConstraints = false
        viewer.addSubview(viewerLabel)
        NSLayoutConstraint.activate([
            viewerLabel.leadingAnchor.constraint(equalTo: viewer.leadingAnchor, constant: 16),
            viewerLabel.bottomAnchor.constraint(equalTo: viewer.bottomAnchor, constant: -16),
        ])
        view.addSubview(viewer)

        progress.progress = 0.35
        let symbolConfiguration = UIImage.SymbolConfiguration(pointSize: 28)
        func controlButton(_ symbol: String, action: @escaping () -> Void) -> UIButton {
            let button = UIButton(type: .system, primaryAction: UIAction { _ in action() })
            button.setImage(UIImage(systemName: symbol, withConfiguration: symbolConfiguration), for: .normal)
            button.tintColor = .white
            return button
        }
        let previous = controlButton("backward.fill") { [weak self] in
            guard let self else { return }
            onSelect(swatch.previous)
        }
        let next = controlButton("forward.fill") { [weak self] in
            guard let self else { return }
            onSelect(swatch.next)
        }
        playButton.addAction(UIAction { [weak self] _ in self?.togglePlay() }, for: .primaryActionTriggered)
        playButton.tintColor = .white
        updatePlayButton()
        let buttons = UIStackView(arrangedSubviews: [previous, playButton, next])
        buttons.spacing = 40

        let thumbnailStack = UIStackView()
        thumbnailStack.spacing = 12
        for candidate in Swatch.all {
            let button = UIButton(type: .custom, primaryAction: UIAction { [weak self] _ in self?.onSelect(candidate) })
            button.layer.cornerRadius = 10
            button.layer.borderColor = UIColor.white.cgColor
            button.widthAnchor.constraint(equalToConstant: 64).isActive = true
            button.heightAnchor.constraint(equalToConstant: 64).isActive = true
            thumbnailStack.addArrangedSubview(button)
            thumbnails.append(button)
        }
        let thumbnailScroll = UIScrollView()
        thumbnailScroll.showsHorizontalScrollIndicator = false
        thumbnailStack.translatesAutoresizingMaskIntoConstraints = false
        thumbnailScroll.addSubview(thumbnailStack)
        NSLayoutConstraint.activate([
            thumbnailStack.topAnchor.constraint(equalTo: thumbnailScroll.contentLayoutGuide.topAnchor),
            thumbnailStack.bottomAnchor.constraint(equalTo: thumbnailScroll.contentLayoutGuide.bottomAnchor),
            thumbnailStack.leadingAnchor.constraint(equalTo: thumbnailScroll.contentLayoutGuide.leadingAnchor),
            thumbnailStack.trailingAnchor.constraint(equalTo: thumbnailScroll.contentLayoutGuide.trailingAnchor),
            thumbnailScroll.heightAnchor.constraint(equalToConstant: 64),
        ])

        let stack = UIStackView(arrangedSubviews: [progress, buttons, thumbnailScroll])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        controls.backgroundColor = UIColor(white: 0.12, alpha: 1)
        controls.layer.cornerRadius = 20
        controls.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: controls.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: controls.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: controls.trailingAnchor, constant: -16),
            progress.widthAnchor.constraint(equalTo: stack.widthAnchor),
            thumbnailScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        view.addSubview(controls)
        render()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let area = view.bounds.inset(by: view.safeAreaInsets).insetBy(dx: pageMargin, dy: pageMargin)
        let foldY = view.bounds.midY
        viewer.frame = CGRect(x: area.minX, y: area.minY, width: area.width, height: max(0, foldY - foldGutter / 2 - area.minY))
        controls.frame = CGRect(x: area.minX, y: foldY + foldGutter / 2, width: area.width, height: max(0, area.maxY - foldY - foldGutter / 2))
    }

    private func togglePlay() {
        isPlaying.toggle()
        updatePlayButton()
    }

    private func updatePlayButton() {
        let symbol = isPlaying ? "pause.fill" : "play.fill"
        playButton.setImage(UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 40)), for: .normal)
    }

    @objc private func swatchStyleDidChange() {
        render()
    }

    private func render() {
        guard isViewLoaded else { return }
        let style = SwatchStyle.current
        viewer.layer.cornerRadius = 16 * style.cornerScale
        UIView.animate(withDuration: 0.25) { self.viewer.backgroundColor = style.color(for: self.swatch) }
        viewerLabel.text = swatch.name
        progress.progressTintColor = swatch.color
        for (candidate, button) in zip(Swatch.all, thumbnails) {
            button.backgroundColor = style.color(for: candidate)
            button.layer.borderWidth = candidate == swatch ? 3 : 0
        }
    }
}

private func pageButton(_ title: String, symbol: String, action: @escaping () -> Void) -> UIButton {
    var configuration = UIButton.Configuration.gray()
    configuration.title = title
    configuration.image = UIImage(systemName: symbol)
    configuration.imagePadding = 6
    return UIButton(configuration: configuration, primaryAction: UIAction { _ in action() })
}
