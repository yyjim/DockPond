import Foundation

enum HingeState: String, CaseIterable, Identifiable {
    case unavailable = "No Hinge"
    case closed = "Closed"
    case partiallyOpen = "Half Open"
    case fullyOpen = "Flat"

    var id: Self { self }
}

enum FoldAxis: String, CaseIterable, Identifiable {
    case vertical = "Vertical"
    case horizontal = "Horizontal"

    var id: Self { self }
}

enum Posture {
    case outer, flat, book, tabletop, compact, regular

    init(state: HingeState, foldAxis: FoldAxis, isRegularWidth: Bool) {
        switch state {
        case .closed: self = .outer
        case .fullyOpen: self = .flat
        case .partiallyOpen: self = foldAxis == .vertical ? .book : .tabletop
        case .unavailable: self = isRegularWidth ? .regular : .compact
        }
    }
}
