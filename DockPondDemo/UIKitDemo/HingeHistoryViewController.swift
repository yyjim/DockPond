import UIKit

/// The last 30 hinge state changes from iOS. A forced hinge state does not add rows.
final class HingeHistoryViewController: UITableViewController {
    private let settings: DuoSettings

    init(settings: DuoSettings) {
        self.settings = settings
        super.init(style: .insetGrouped)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Hinge History"
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        NotificationCenter.default.addObserver(self, selector: #selector(historyDidChange), name: DuoSettings.historyDidChange, object: settings)
    }

    @objc private func historyDidChange() {
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(1, settings.events.count)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.selectionStyle = .none
        var content = cell.defaultContentConfiguration()
        if settings.events.isEmpty {
            content.text = "No hinge updates yet. Fold or open the device."
            content.textProperties.color = .secondaryLabel
        } else {
            let event = settings.events[indexPath.row]
            content.text = [event.reading.state.rawValue, event.reading.angleDegrees.map { "\($0)°" }]
                .compactMap { $0 }
                .joined(separator: "  ")
            content.secondaryText = event.date.formatted(date: .omitted, time: .standard)
        }
        cell.contentConfiguration = content
        return cell
    }
}
