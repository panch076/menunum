import AppKit
import Combine
import SwiftUI

/// A menu bar item that shows an ``AnimatedNumber``.
///
///     let item = AnimatedStatusItem()
///     item.number.set(42)
///     item.number.countdown(from: 25 * 60)
///     item.menu = myMenu
///
/// Keep a strong reference to it; the item disappears when it is deallocated.
@MainActor
public final class AnimatedStatusItem {
    public let number: AnimatedNumber
    public let statusItem: NSStatusItem

    /// The menu shown when the item is clicked.
    public var menu: NSMenu? {
        get { statusItem.menu }
        set { statusItem.menu = newValue }
    }

    private let hostingView: NSView
    private let idleSymbol: String?
    private let font: Font
    private var cancellable: AnyCancellable?
    private var shrinkWork: DispatchWorkItem?

    /// - Parameters:
    ///   - number: The state to display; a new one is created if omitted.
    ///   - idleSymbol: SF Symbol shown while `number.mode == .idle`; `nil` shows the value instead.
    ///   - font: Font for the digits.
    public init(
        number: AnimatedNumber? = nil,
        idleSymbol: String? = "number",
        font: Font = .system(size: 13, weight: .medium)
    ) {
        let number = number ?? AnimatedNumber()
        self.number = number
        self.idleSymbol = idleSymbol
        self.font = font
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        hostingView = PassthroughHostingView(
            rootView: StatusItemLabel(number: number, idleSymbol: idleSymbol, font: font)
        )

        let button = statusItem.button!
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(hostingView)
        NSLayoutConstraint.activate([
            hostingView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: button.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
        ])

        // objectWillChange fires before the change; hop a runloop turn to measure the new size.
        cancellable = number.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.resize() }
        resize()
    }

    /// Sizes the item for the new value. The live view may be mid-animation, so the final
    /// state is measured off-screen; while animating, the item keeps the wider of the old and
    /// new widths so nothing is clipped, then shrinks to fit once the animation ends.
    private func resize() {
        let target = ceil(NSHostingView(rootView: measuringLabel).fittingSize.width)
        shrinkWork?.cancel()
        if target >= statusItem.length {
            statusItem.length = target
            return
        }
        let work = DispatchWorkItem { [weak self] in self?.statusItem.length = target }
        shrinkWork = work
        let delay = (number.duration ?? number.style.defaultDuration) + 0.1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private var measuringLabel: some View {
        Group {
            if number.mode == .idle, let idleSymbol {
                Image(systemName: idleSymbol)
            } else {
                Text(number.text).monospacedDigit()
            }
        }
        .font(font)
        .fixedSize()
        .padding(.horizontal, 4)
    }
}

/// Hosting view that lets clicks fall through to the status item button (so its menu opens).
private final class PassthroughHostingView<Content: View>: NSHostingView<Content> {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private struct StatusItemLabel: View {
    @ObservedObject var number: AnimatedNumber
    let idleSymbol: String?
    let font: Font

    var body: some View {
        Group {
            if number.mode == .idle, let idleSymbol {
                Image(systemName: idleSymbol)
            } else {
                AnimatedNumberText(
                    value: number.value,
                    style: number.style,
                    format: number.format,
                    prefix: number.prefix,
                    suffix: number.suffix,
                    duration: number.duration
                )
            }
        }
        .font(font)
        .fixedSize()
        .padding(.horizontal, 4)
        .frame(maxHeight: .infinity)
    }
}
