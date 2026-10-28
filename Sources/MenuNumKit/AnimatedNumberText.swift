import SwiftUI

/// A text view that animates whenever `value` changes. Works anywhere in SwiftUI,
/// including `MenuBarExtra` labels.
///
///     AnimatedNumberText(value: count, style: .roll)
///         .font(.title)
public struct AnimatedNumberText: View {
    public var value: Double
    public var style: AnimationStyle
    public var format: DisplayFormat
    public var prefix: String
    public var suffix: String
    /// Animation length in seconds; `nil` uses the style's default.
    public var duration: Double?

    public init(
        value: Double,
        style: AnimationStyle = .roll,
        format: DisplayFormat = .number(decimals: 0),
        prefix: String = "",
        suffix: String = "",
        duration: Double? = nil
    ) {
        self.value = value
        self.style = style
        self.format = format
        self.prefix = prefix
        self.suffix = suffix
        self.duration = duration
    }

    private func text(_ v: Double) -> String { prefix + format.render(v) + suffix }

    private var animation: Animation {
        let d = duration ?? style.defaultDuration
        switch style {
        case .roll: return .snappy(duration: d)
        case .tween: return .easeOut(duration: d)
        case .fade: return .easeInOut(duration: d)
        }
    }

    public var body: some View {
        content
            .monospacedDigit()
            .animation(animation, value: value)
    }

    @ViewBuilder private var content: some View {
        switch style {
        case .roll:
            Text(text(value))
                .contentTransition(.numericText(value: value))
        case .tween:
            TweenText(value: value, render: text)
        case .fade:
            ZStack {
                Text(text(value))
                    .id(text(value))
                    .transition(.opacity.combined(with: .scale(scale: 0.85)))
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
