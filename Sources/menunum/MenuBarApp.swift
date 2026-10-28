import AppKit
import Combine
import SwiftUI

/// Hosting view that lets clicks fall through to the status item button (so its menu opens).
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class MenuBarApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let ticker = Ticker()
    private var statusItem: NSStatusItem!
    private var hostingView: NSView!
    private var cancellables: Set<AnyCancellable> = []

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
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let button = statusItem.button!

        hostingView = PassthroughHostingView(rootView: TickerView(ticker: ticker))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        ticker.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.resize() }
            .store(in: &cancellables)
        resize()

        DistributedNotificationCenter.default().addObserver(
            forName: IPC.notification, object: nil, queue: .main
        ) { [weak self] note in
            guard let cmd = IPC.decode(note) else { return }
            MainActor.assumeIsolated { self?.ticker.apply(cmd) }
        }

        // Written last so the CLI only sends once we're listening.
        try? String(getpid()).write(to: IPC.pidFile, atomically: true, encoding: .utf8)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if IPC.runningPID() == getpid() {
            try? FileManager.default.removeItem(at: IPC.pidFile)
        }
    }

    private func resize() {
        statusItem.length = ceil(hostingView.fittingSize.width)
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if ticker.mode == .countdown || ticker.mode == .stopwatch {
            if ticker.isPaused {
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
            i.state = ticker.style == style ? .on : .off
            styleMenu.addItem(i)
        }
        let styleItem = NSMenuItem(title: "Animation", action: nil, keyEquivalent: "")
        styleItem.submenu = styleMenu
        menu.addItem(styleItem)

        if ticker.mode != .idle {
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

    @objc private func pause() { ticker.apply(Command(action: .pause)) }
    @objc private func resume() { ticker.apply(Command(action: .resume)) }
    @objc private func restart() { ticker.restart() }
    @objc private func clear() { ticker.apply(Command(action: .clear)) }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func chooseStyle(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let style = AnimationStyle(rawValue: raw) else { return }
        ticker.apply(Command(action: .style, style: style))
    }
}
