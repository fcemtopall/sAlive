import Foundation

/// Where the user wants sAlive's controls to appear.
///
/// The Control Center toggle talks to the helper directly, so it works even
/// when the menu bar app is hidden or not running. macOS doesn't let apps add
/// or remove Control Center controls themselves – the user does that via
/// Control Center › Edit Controls – so for that surface we only guide them.
enum Placement: String, CaseIterable, Identifiable {
    case both
    case controlCenter
    case menuBar

    static let defaultsKey = "placement"

    static var current: Placement {
        UserDefaults.standard.string(forKey: defaultsKey).flatMap(Placement.init(rawValue:)) ?? .both
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .both: return "Menu bar & Control Center"
        case .controlCenter: return "Control Center only"
        case .menuBar: return "Menu bar only"
        }
    }

    var showsMenuBar: Bool { self != .controlCenter }
    var usesControlCenter: Bool { self != .menuBar }
}
