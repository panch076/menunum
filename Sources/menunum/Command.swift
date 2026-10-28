import Foundation

/// How a value change is animated in the menu bar.
enum AnimationStyle: String, Codable, CaseIterable {
    /// Each changed digit rolls vertically (like the Clock app timer).
    case roll
    /// The number counts from the old value to the new one.
    case tween
    /// The old value cross-fades into the new one.
    case fade

    var defaultDuration: Double {
        switch self {
        case .roll: return 0.45
        case .tween: return 0.8
        case .fade: return 0.35
        }
    }
}

/// How the numeric value is rendered as text.
enum DisplayFormat: Codable, Equatable {
    case number(decimals: Int)
    /// Seconds rendered as m:ss or h:mm:ss.
    case time

    func render(_ value: Double) -> String {
        switch self {
        case .number(let decimals):
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.minimumFractionDigits = decimals
            f.maximumFractionDigits = decimals
            return f.string(from: NSNumber(value: value)) ?? String(value)
        case .time:
            let total = max(0, Int(value.rounded()))
            let h = total / 3600, m = (total % 3600) / 60, s = total % 60
            return h > 0
                ? String(format: "%d:%02d:%02d", h, m, s)
                : String(format: "%d:%02d", m, s)
        }
    }
}

/// A message sent from the CLI to the running menu bar process.
struct Command: Codable {
    enum Action: String, Codable {
        case set, countdown, stopwatch, pause, resume, clear, style, quit
    }

    var action: Action
    var value: Double?
    var format: DisplayFormat?
    var style: AnimationStyle?
    var duration: Double?
    var prefix: String?
    var suffix: String?
}

/// IPC between the CLI and the menu bar process via distributed notifications.
enum IPC {
    static let notification = Notification.Name("dev.menunum.command")

    static var supportDir: URL {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/menunum", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var pidFile: URL { supportDir.appendingPathComponent("menunum.pid") }

    /// PID of the running menu bar process, if any.
    static func runningPID() -> pid_t? {
        guard let text = try? String(contentsOf: pidFile, encoding: .utf8),
              let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)),
              kill(pid, 0) == 0
        else { return nil }
        return pid
    }

    static func send(_ command: Command) {
        let data = try! JSONEncoder().encode(command)
        DistributedNotificationCenter.default().postNotificationName(
            notification,
            object: String(decoding: data, as: UTF8.self),
            userInfo: nil,
            deliverImmediately: true
        )
    }

    static func decode(_ note: Notification) -> Command? {
        guard let json = note.object as? String else { return nil }
        return try? JSONDecoder().decode(Command.self, from: Data(json.utf8))
    }
}
