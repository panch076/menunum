import Foundation

/// Observable state for an animated number, with built-in countdown and stopwatch clocks.
/// Display it with ``AnimatedStatusItem`` or ``AnimatedNumberText``.
@MainActor
public final class AnimatedNumber: ObservableObject {
    public enum Mode: Sendable { case idle, value, countdown, stopwatch }

    @Published public private(set) var value: Double = 0
    @Published public private(set) var mode: Mode = .idle
    @Published public private(set) var isPaused = false
    @Published public var style: AnimationStyle
    @Published public var format: DisplayFormat
    @Published public var prefix: String
    @Published public var suffix: String
    /// Animation length in seconds; `nil` uses the style's default.
    @Published public var duration: Double?

    /// Called when a countdown reaches zero.
    public var onCountdownFinished: (() -> Void)?

    private var timer: Timer?
    private var countdownStart: Double = 0

    public init(
        style: AnimationStyle = .roll,
        format: DisplayFormat = .number(decimals: 0),
        prefix: String = "",
        suffix: String = ""
    ) {
        self.style = style
        self.format = format
        self.prefix = prefix
        self.suffix = suffix
    }

    /// The fully formatted string, including prefix and suffix.
    public var text: String { prefix + format.render(value) + suffix }

    /// Shows a static value, stopping any running clock.
    public func set(_ newValue: Double, format: DisplayFormat? = nil) {
        stopTimer()
        if let format { self.format = format }
        mode = .value
        value = newValue
    }

    /// Counts down once per second from `seconds` to zero.
    public func countdown(from seconds: Double) {
        format = .time
        countdownStart = seconds
        mode = .countdown
        value = seconds
        startTimer()
    }

    /// Counts up once per second from `seconds`.
    public func stopwatch(from seconds: Double = 0) {
        format = .time
        mode = .stopwatch
        value = seconds
        startTimer()
    }

    public func pause() {
        guard timer != nil else { return }
        stopTimer()
        isPaused = true
    }

    public func resume() {
        if isPaused { startTimer() }
    }

    /// Restarts the current countdown or stopwatch from the beginning.
    public func restart() {
        switch mode {
        case .countdown: countdown(from: countdownStart)
        case .stopwatch: stopwatch()
        default: break
        }
    }

    /// Stops any clock and returns to the idle state.
    public func clear() {
        stopTimer()
        mode = .idle
        value = 0
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
            value = max(0, value - 1)
            if value == 0 {
                stopTimer()
                onCountdownFinished?()
            }
        case .stopwatch:
            value += 1
        default:
            stopTimer()
        }
    }
}
