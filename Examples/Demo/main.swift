// A minimal app using MenuNumKit: a menu bar counter that jumps to a random
// value every two seconds, cycling through the animation styles.
//
//     swift run menunum-demo

import AppKit
import MenuNumKit

@MainActor
final class Demo: NSObject, NSApplicationDelegate {
    var item: AnimatedStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = AnimatedStatusItem(number: AnimatedNumber(prefix: "$"))

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu

        var tick = 0
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let number = self?.item.number else { return }
                number.style = AnimationStyle.allCases[(tick / 3) % AnimationStyle.allCases.count]
                number.set(Double(Int.random(in: 0...9_999)))
                tick += 1
            }
        }
    }
}

let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { Demo() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
