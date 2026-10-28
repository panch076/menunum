import Foundation

/// How a value change is animated.
public enum AnimationStyle: String, Codable, CaseIterable, Sendable {
    /// Each changed digit rolls vertically (like the Clock app timer).
    case roll
    /// The number counts from the old value to the new one.
    case tween
    /// The old value cross-fades into the new one.
    case fade

    public var defaultDuration: Double {
        switch self {
        case .roll: return 0.45
        case .tween: return 0.8
        case .fade: return 0.35
        }
    }
}

/// How a numeric value is rendered as text.
public enum DisplayFormat: Codable, Equatable, Sendable {
    /// A grouped decimal number, e.g. `1,337.50`.
    case number(decimals: Int)
    /// Seconds rendered as `m:ss` or `h:mm:ss`.
    case time

    public func render(_ value: Double) -> String {
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
