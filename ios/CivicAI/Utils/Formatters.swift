import Foundation

/// Locale-aware value formatting. Charts, cards and VoiceOver all read from here
/// so a number never appears two different ways in the app.
enum Format {

    private static let currency: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.maximumFractionDigits = 0
        return f
    }()

    private static let integer: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f
    }()

    static func value(_ value: Double, as format: MetricFormat) -> String {
        switch format {
        case .currency:
            return currency.string(from: value as NSNumber) ?? "$\(Int(value))"
        case .percent:
            return String(format: "%.1f%%", value)
        case .integer:
            return integer.string(from: value as NSNumber) ?? "\(Int(value))"
        }
    }

    /// Compact axis labels: 48,500 -> "48.5K", 1,240,000 -> "1.2M".
    static func compact(_ value: Double, as format: MetricFormat) -> String {
        if format == .percent { return String(format: "%.0f%%", value) }
        let prefix = format == .currency ? (currency.currencySymbol ?? "$") : ""
        let magnitude = abs(value)
        switch magnitude {
        case 1_000_000...:
            return prefix + String(format: "%.1fM", value / 1_000_000)
        case 10_000...:
            return prefix + String(format: "%.0fK", value / 1_000)
        case 1_000...:
            return prefix + String(format: "%.1fK", value / 1_000)
        default:
            return prefix + (integer.string(from: value as NSNumber) ?? "\(Int(value))")
        }
    }

    static func percentChange(_ percent: Double) -> String {
        String(format: "%@%.1f%%", percent >= 0 ? "+" : "−", abs(percent))
    }

    /// "down 0.8 points over 5 years" / "up 28.6% over 10 years".
    static func changeSummary(_ change: MetricChange, format: MetricFormat) -> String {
        let unitWord = format == .percent ? "points" : nil
        let magnitude: String
        if let unitWord {
            magnitude = String(format: "%.1f %@", abs(change.absoluteChange), unitWord)
        } else if let percent = change.percentChange {
            magnitude = String(format: "%.1f%%", abs(percent))
        } else {
            magnitude = value(abs(change.absoluteChange), as: format)
        }
        let direction = change.absoluteChange > 0 ? "up" : (change.absoluteChange < 0 ? "down" : "unchanged")
        return "\(direction) \(magnitude) over \(change.spanYears) years"
    }

    /// ISO-8601 "2024-12-01" -> "December 2024". Falls back to the raw string.
    static func monthYear(_ isoDate: String?) -> String? {
        guard let isoDate else { return nil }
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        input.locale = Locale(identifier: "en_US_POSIX")
        guard let date = input.date(from: String(isoDate.prefix(10))) else { return isoDate }
        let output = DateFormatter()
        output.dateFormat = "MMMM yyyy"
        return output.string(from: date)
    }
}
