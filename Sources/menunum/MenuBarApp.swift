import AppKit
import MenuNumKit

/// The `menunum run` process: an ``AnimatedStatusItem`` controlled by CLI commands.
@MainActor
final class MenuBarApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var item: AnimatedStatusItem!
    private var number: AnimatedNumber { item.number }

    static func run() {
        // Survive the launching terminal closing.
        signal(SIGHUP, SIG_IGN)

        if let pid = IPC.runningPID(), pid != getpid() {
            FileHandle.standardError.write("menunum is already running (pid \(pid))\n".data(using: .utf8)!)
            exit(0)
        }

        let app = NSApplication.shared
        let delegate = MenuBarApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = AnimatedStatusItem()
        number.onCountdownFinished = { NSSound(named: "Glass")?.play() }

        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu

        DistributedNotificationCenter.default().addObserver(
            forName: IPC.notification, object: nil, queue: .main
        ) { [weak self] note in
            guard let cmd = IPC.decode(note) else { return }
            MainActor.assumeIsolated { self?.apply(cmd) }
        }

        // Written last so the CLI only sends once we're listening.
        try? String(getpid()).write(to: IPC.pidFile, atomically: true, encoding: .utf8)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if IPC.runningPID() == getpid() {
            try? FileManager.default.removeItem(at: IPC.pidFile)
        }
    }

    private func apply(_ cmd: Command) {
        if let s = cmd.style { number.style = s }
        if let d = cmd.duration { number.duration = d }
        // Prefix/suffix belong to a value, so a new value without them clears them.
        if [.set, .countdown, .stopwatch].contains(cmd.action) {
            number.prefix = cmd.prefix ?? ""
            number.suffix = cmd.suffix ?? ""
        }

        switch cmd.action {
        case .set: number.set(cmd.value ?? 0, format: cmd.format)
        case .countdown: number.countdown(from: cmd.value ?? 0)
        case .stopwatch: number.stopwatch()
        case .pause: number.pause()
        case .resume: number.resume()
        case .clear: number.clear()
        case .style: break
        case .quit: NSApp.terminate(nil)
        }
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if number.mode == .countdown || number.mode == .stopwatch {
            if number.isPaused {
                menu.addItem(item("Resume", #selector(resume)))
            } else {
                menu.addItem(item("Pause", #selector(pause)))
            }
            menu.addItem(item("Restart", #selector(restart)))
            menu.addItem(.separator())
        }

        let styleMenu = NSMenu()
        for style in AnimationStyle.allCases {
            let i = item(style.rawValue.capitalized, #selector(chooseStyle(_:)))
            i.representedObject = style.rawValue
            i.state = number.style == style ? .on : .off
            styleMenu.addItem(i)
        }
        let styleItem = NSMenuItem(title: "Animation", action: nil, keyEquivalent: "")
        styleItem.submenu = styleMenu
        menu.addItem(styleItem)

        if number.mode != .idle {
            menu.addItem(item("Clear", #selector(clear)))
        }
        menu.addItem(.separator())
        menu.addItem(item("Quit menunum", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func pause() { number.pause() }
    @objc private func resume() { number.resume() }
    @objc private func restart() { number.restart() }
    @objc private func clear() { number.clear() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func chooseStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let style = AnimationStyle(rawValue: raw) else { return }
        number.style = style
    }
}
