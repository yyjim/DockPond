import FloatingDock
import UIKit

/// The gauge rows as a UIKit view, for use inside a floating dock or any other view.
public final class LayoutGaugeUIView: UIView {
    private let sections: LayoutGauge.Sections
    private let stack = UIStackView()
    private var observations: [GaugeObservation] = []
    private var rows: [GaugeRow] = []

    public init(gauge: LayoutGauge, sections: LayoutGauge.Sections = .all) {
        self.sections = sections
        super.init(frame: .zero)
        stack.axis = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        observations.append(gauge.observe { [weak self] in self?.render($0) })
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func retain(_ observation: GaugeObservation) {
        observations.append(observation)
    }

    private func render(_ snapshot: LayoutGauge.Snapshot) {
        let newRows = snapshot.rows(for: sections)
        guard newRows != rows else { return }
        rows = newRows
        for view in stack.arrangedSubviews {
            view.removeFromSuperview()
        }
        for row in rows {
            stack.addArrangedSubview(GaugeRowView(row: row))
        }
        invalidateIntrinsicContentSize()
    }
}

extension FloatingDockController {
    /// Creates a floating dock whose panel shows the layout gauge. The dock title
    /// and icon follow the gauge. Call `install(in:)` on the result.
    public static func gaugeDock(
        _ gauge: LayoutGauge,
        sections: LayoutGauge.Sections = .all,
        configuration: FloatingDockConfiguration = FloatingDockConfiguration(id: "gauge")
    ) -> FloatingDockController {
        let contentView = LayoutGaugeUIView(gauge: gauge, sections: sections)
        let dock = FloatingDockController(
            title: gauge.snapshot.title,
            systemImage: gauge.snapshot.symbol,
            configuration: configuration,
            contentView: contentView
        )
        contentView.retain(gauge.observe { [weak dock] snapshot in
            dock?.title = snapshot.title
            dock?.systemImage = snapshot.symbol
        })
        return dock
    }
}

private final class GaugeRowView: UIView {
    init(row: GaugeRow) {
        super.init(frame: .zero)
        let font = UIFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        let nameLabel = UILabel()
        nameLabel.text = row.name
        nameLabel.font = font
        nameLabel.textColor = .secondaryLabel
        nameLabel.widthAnchor.constraint(equalToConstant: 90).isActive = true
        let valueLabel = UILabel()
        valueLabel.text = row.value
        valueLabel.font = font
        valueLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [nameLabel, valueLabel])
        stack.spacing = 10
        stack.alignment = .firstBaseline
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
}
