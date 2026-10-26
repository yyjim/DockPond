import Observation
import UIKit

/// Measures the layout environment of one window: its size, the screen, the
/// orientation, size classes, safe area, display scale, and the hinge and fold on
/// devices that have one.
///
/// SwiftUI: attach it with `.layoutGauge(_:)` and read `snapshot`.
/// UIKit: call `attach(to:)` with the app's window, and read `snapshot` or
/// register a handler with `observe(_:)`.
@MainActor
@Observable
public final class LayoutGauge {
    public private(set) var snapshot = Snapshot.empty

    @ObservationIgnored private weak var probe: GaugeProbeView?
    @ObservationIgnored private var observers: [(token: WeakObservation, handler: @MainActor (Snapshot) -> Void)] = []

    public init() {}

    /// Starts measuring `window`. Calling it again with another window moves the
    /// gauge to that window.
    public func attach(to window: UIWindow) {
        guard probe?.window !== window else { return }
        probe?.removeFromSuperview()
        let probe = GaugeProbeView { [weak self] in self?.update($0) }
        probe.frame = window.bounds
        probe.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.insertSubview(probe, at: 0)
        self.probe = probe
    }

    public func detach() {
        probe?.removeFromSuperview()
        probe = nil
    }

    /// Calls `handler` now and after every change. The handler stays registered
    /// while the returned observation is alive.
    public func observe(_ handler: @escaping @MainActor (Snapshot) -> Void) -> GaugeObservation {
        let observation = GaugeObservation()
        observers.append((WeakObservation(value: observation), handler))
        handler(snapshot)
        return observation
    }

    private func update(_ newSnapshot: Snapshot) {
        guard newSnapshot != snapshot else { return }
        snapshot = newSnapshot
        observers.removeAll { $0.token.value == nil }
        for observer in observers {
            observer.handler(newSnapshot)
        }
    }
}

/// Keeps an `observe(_:)` handler registered. Release it to stop the handler.
public final class GaugeObservation {}

private struct WeakObservation {
    weak var value: GaugeObservation?
}

extension LayoutGauge {
    public struct Snapshot: Equatable, Sendable {
        public var windowSize: CGSize
        public var screenSize: CGSize
        /// True when the window is smaller than the screen, for example in split
        /// screen, Stage Manager, or a resized scene.
        public var isResized: Bool
        public var interfaceOrientation: UIInterfaceOrientation
        public var horizontalSizeClass: UIUserInterfaceSizeClass
        public var verticalSizeClass: UIUserInterfaceSizeClass
        public var safeAreaInsets: UIEdgeInsets
        public var displayScale: CGFloat
        /// The hinge on iOS 27.1 and later, or nil on a device without one.
        public var hinge: Hinge?
        /// The posture and the estimated fold line, or nil on a device without a hinge.
        public var fold: Fold?

        /// True when the window is wider than it is tall.
        public var isLandscape: Bool { windowSize.width > windowSize.height }

        public static let empty = Snapshot(
            windowSize: .zero,
            screenSize: .zero,
            isResized: false,
            interfaceOrientation: .unknown,
            horizontalSizeClass: .unspecified,
            verticalSizeClass: .unspecified,
            safeAreaInsets: .zero,
            displayScale: 0,
            hinge: nil,
            fold: nil
        )
    }

    public struct Hinge: Equatable, Sendable {
        public enum State: String, Sendable {
            case closed = "Closed"
            case partiallyOpen = "Half Open"
            case fullyOpen = "Flat"
        }

        public var state: State
        public var angle: Measurement<UnitAngle>
    }

    /// The posture of a foldable device, and where the fold line probably is.
    ///
    /// iOS reports the hinge state and angle, but not where the fold is on the
    /// screen. The gauge estimates it: the fold crosses the longer edge of the
    /// screen at its middle. Check `axis` and `position` against a real device.
    public struct Fold: Equatable, Sendable {
        public enum Posture: String, Sendable {
            case closed = "Closed"
            case flat = "Flat"
            case book = "Book"
            case tabletop = "Tabletop"
        }

        public enum Axis: String, Sendable {
            case vertical = "Vertical"
            case horizontal = "Horizontal"
        }

        public var posture: Posture
        /// The direction of the fold line, or nil when the device is closed.
        public var axis: Axis?
        /// The x (vertical fold) or y (horizontal fold) of the fold line in window
        /// coordinates. Nil when the device is closed or the fold is outside the window.
        public var position: CGFloat?
    }

    public struct Sections: OptionSet, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static let window = Sections(rawValue: 1 << 0)
        public static let orientation = Sections(rawValue: 1 << 1)
        public static let sizeClasses = Sections(rawValue: 1 << 2)
        public static let safeArea = Sections(rawValue: 1 << 3)
        public static let scale = Sections(rawValue: 1 << 4)
        public static let hinge = Sections(rawValue: 1 << 5)
        /// Posture and estimated fold line. Shown only on a device with a hinge.
        public static let fold = Sections(rawValue: 1 << 6)
        public static let all: Sections = [.window, .orientation, .sizeClasses, .safeArea, .scale, .hinge, .fold]
    }
}
