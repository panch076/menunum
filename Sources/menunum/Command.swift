import Foundation
import MenuNumKit

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
