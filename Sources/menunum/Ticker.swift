import AppKit
import SwiftUI

/// The state shown in the menu bar, plus the countdown/stopwatch clock.
@MainActor
final class Ticker: ObservableObject {
    enum Mode { case idle, value, countdown, stopwatch }

    @Published private(set) var value: Double = 0
    @Published private(set) var mode: Mode = .idle
    @Published var style: AnimationStyle = .roll
    @Published var format: DisplayFormat = .number(decimals: 0)
    @Published var prefix = ""
    @Published var suffix = ""
    @Published private(set) var isPaused = false

    var duration: Double?
    private var timer: Timer?
    private var countdownStart: Double = 0

    var text: String { prefix + format.render(value) + suffix }

    var animation: Animation {
        let d = duration ?? style.defaultDuration
        switch style {
        case .roll: return .snappy(duration: d)
        case .tween: return .easeOut(duration: d)
        case .fade: return .easeInOut(duration: d)
        }
    }

    func apply(_ cmd: Command) {
        if let s = cmd.style { style = s }
        if let d = cmd.duration { duration = d }
        // Prefix/suffix belong to a value, so a new value without them clears them.
        if [.set, .countdown, .stopwatch].contains(cmd.action) {
            prefix = cmd.prefix ?? ""
            suffix = cmd.suffix ?? ""
        }

        switch cmd.action {
        case .set:
            stopTimer()
            if let f = cmd.format { format = f }
            mode = .value
            animate(to: cmd.value ?? 0)
        case .countdown:
            format = .time
            countdownStart = cmd.value ?? 0
            mode = .countdown
            animate(to: countdownStart)
            startTimer()
        case .stopwatch:
            format = .time
            mode = .stopwatch
            animate(to: 0)
            startTimer()
        case .pause:
            if timer != nil { stopTimer(); isPaused = true }
        case .resume:
            if isPaused { startTimer() }
        case .clear:
            stopTimer()
            mode = .idle
            prefix = ""; suffix = ""
            value = 0
        case .style:
            break
        case .quit:
            NSApp.terminate(nil)
        }
    }

    func restart() {
        switch mode {
        case .countdown: apply(Command(action: .countdown, value: countdownStart))
        case .stopwatch: apply(Command(action: .stopwatch))
        default: break
        }
    }

    private func animate(to newValue: Double) {
        withAnimation(animation) { value = newValue }
    }

    private func startTimer() {
        timer?.invalidate()
        isPaused = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isPaused = false
    }

    private func tick() {
        switch mode {
        case .countdown:
            let next = max(0, value - 1)
            animate(to: next)
            if next == 0 {
                stopTimer()
                NSSound(named: "Glass")?.play()
            }
        case .stopwatch:
            animate(to: value + 1)
        default:
            stopTimer()
        }
    }
}

/// The SwiftUI view hosted inside the status item.
struct TickerView: View {
    @ObservedObject var ticker: Ticker

    var body: some View {
        content
            .font(.system(size: 13, weight: .medium).monospacedDigit())
            .fixedSize()
            .padding(.horizontal, 4)
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder private var content: some View {
        if ticker.mode == .idle {
            Image(systemName: "number")
        } else {
            switch ticker.style {
            case .roll:
                Text(ticker.text)
                    .contentTransition(.numericText(value: ticker.value))
            case .tween:
                TweenText(value: ticker.value) { [prefix = ticker.prefix, suffix = ticker.suffix, format = ticker.format] v in
                    prefix + format.render(v) + suffix
                }
            case .fade:
                ZStack {
                    Text(ticker.text)
                        .id(ticker.text)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                }
            }
        }
    }
}

/// Text whose numeric value is interpolated frame-by-frame by SwiftUI's animation system.
private struct TweenText: View, Animatable {
    var value: Double
    let render: (Double) -> String

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View { Text(render(value)) }
}
