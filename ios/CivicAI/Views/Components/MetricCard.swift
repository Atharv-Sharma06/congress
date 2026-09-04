import SwiftUI

/// Dashboard tile. Reads as one element to VoiceOver: name, value, year, trend.
struct MetricCard: View {
    let metric: Metric
    var showsSparkline: Bool = true

    @ScaledMetric(relativeTo: .footnote) private var symbolSize: CGFloat = 13

    var body: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                HStack(spacing: Theme.Space.sm) {
                    Image(systemName: metric.sfSymbol)
                        .font(.system(size: symbolSize, weight: .semibold))
                        .foregroundStyle(Theme.Palette.primary)
                    Text(metric.name.uppercased())
                        .font(.footnote.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(Theme.Palette.foregroundMuted)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    // No lineLimit: at the largest Dynamic Type sizes this must wrap,
                    // not truncate. AnimatedValue rolls only the digits that changed
                    // when a refresh brings in a new year.
                    AnimatedValue(value: metric.currentValue, format: metric.format)
                        .font(.title.weight(.bold))
                        .foregroundStyle(Theme.Palette.foreground)
                        .minimumScaleFactor(0.8)

                    Text("as of \(String(metric.currentYear))")
                        .font(.caption)
                        .foregroundStyle(Theme.Palette.foregroundMuted)
                }

                if let change = metric.headlineChange {
                    TrendPill(trend: metric.trend, change: change, format: metric.format)
                }

                if showsSparkline, metric.history.count > 2 {
                    Sparkline(history: metric.history)
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Opens the full trend, definition and data source.")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityLabel: String {
        var parts = [
            metric.name,
            "\(Format.value(metric.currentValue, as: metric.format)) as of \(metric.currentYear)",
        ]
        if let change = metric.headlineChange {
            parts.append(Format.changeSummary(change, format: metric.format))
        }
        return parts.joined(separator: ", ")
    }
}

/// Slim single-line row used in category lists, where the sparkline would be noise.
struct MetricRow: View {
    let metric: Metric

    var body: some View {
        HStack(spacing: Theme.Space.md) {
            Image(systemName: metric.sfSymbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(Theme.Palette.primary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(metric.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.Palette.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                if let change = metric.headlineChange {
                    HStack(spacing: Theme.Space.xs) {
                        Image(systemName: metric.trend.direction.sfSymbol)
                            .font(.caption2.weight(.bold))
                        Text(Format.changeSummary(change, format: metric.format))
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(metric.trend.sentiment.color)
                }
            }

            Spacer(minLength: Theme.Space.sm)

            AnimatedValue(value: metric.currentValue, format: metric.format)
                .font(.headline)
                .foregroundStyle(Theme.Palette.foreground)
        }
        .padding(.vertical, Theme.Space.sm)
        .frame(minHeight: Theme.minTapTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [
                metric.name,
                Format.value(metric.currentValue, as: metric.format),
                metric.headlineChange.map { Format.changeSummary($0, format: metric.format) },
            ]
            .compactMap { $0 }
            .joined(separator: ", ")
        )
        .accessibilityAddTraits(.isButton)
    }
}
