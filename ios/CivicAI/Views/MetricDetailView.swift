import SwiftUI

/// One measure in full: value, trend, 10-year chart, plain-English definition,
/// provenance, and the neighbouring measures worth looking at next.
struct MetricDetailView: View {
    let metric: Metric

    @EnvironmentObject private var store: MetricsStore
    @State private var showingSources = false

    private var related: [Metric] {
        guard let bundle = store.bundle else { return [] }
        return bundle.metrics(in: metric.category).filter { $0.id != metric.id }.prefix(3).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                valueBlock
                chartBlock
                definitionBlock
                sourceBlock
                if !related.isEmpty { relatedBlock }
            }
            .padding(Theme.Space.lg)
        }
        .appBackground()
        .navigationTitle(metric.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSources) {
            SourceSheet(
                sources: [sourceWithMetricName],
                metricDefinition: metric.definition
            )
        }
    }

    private var sourceWithMetricName: Source {
        var source = metric.source
        source.metricName = metric.name
        return source
    }

    // MARK: - Blocks

    private var valueBlock: some View {
        CardSurface {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Label(metric.category, systemImage: metric.sfSymbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Palette.primary)

                AnimatedValue(value: metric.currentValue, format: metric.format)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Theme.Palette.foreground)
                    .minimumScaleFactor(0.7)

                Text("as of \(String(metric.currentYear))")
                    .font(.subheadline)
                    .foregroundStyle(Theme.Palette.foregroundMuted)

                VStack(alignment: .leading, spacing: Theme.Space.sm) {
                    if let five = metric.changeFiveYear {
                        TrendPill(trend: metric.trend, change: five, format: metric.format)
                    }
                    if let ten = metric.changeTenYear, ten.spanYears != metric.changeFiveYear?.spanYears {
                        TrendPill(trend: metric.trend, change: ten, format: metric.format)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var chartBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            SectionHeader(
                title: "Trend over time",
                subtitle: metric.history.count > 1
                    ? "\(metric.history.first!.year) to \(metric.history.last!.year). Touch and drag to read a year."
                    : nil
            )
            CardSurface {
                TrendChart(
                    history: metric.history,
                    format: metric.format,
                    metricName: metric.name,
                    lineColor: Theme.Palette.accent
                )
            }
        }
    }

    private var definitionBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            SectionHeader(title: "What does this mean?")
            CardSurface {
                Text(metric.definition)
                    .font(.body)
                    .foregroundStyle(Theme.Palette.foreground)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var sourceBlock: some View {
        Button {
            Haptics.tap()
            showingSources = true
        } label: {
            CardSurface {
                HStack(spacing: Theme.Space.md) {
                    Image(systemName: "link.circle")
                        .font(.title3)
                        .foregroundStyle(Theme.Palette.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Where does this come from?")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.Palette.foreground)
                        Text(metric.source.organization)
                            .font(.caption)
                            .foregroundStyle(Theme.Palette.foregroundMuted)
                    }
                    Spacer(minLength: Theme.Space.sm)
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.Palette.foregroundMuted)
                }
                .frame(minHeight: Theme.minTapTarget)
            }
        }
        .buttonStyle(PressableCardStyle())
        .accessibilityLabel("Where does this come from? Source: \(metric.source.organization)")
        .accessibilityHint("Opens dataset details and a link to the original data.")
    }

    private var relatedBlock: some View {
        VStack(alignment: .leading, spacing: Theme.Space.md) {
            SectionHeader(title: "Related in \(metric.category)")
            CardSurface(padding: Theme.Space.md) {
                VStack(spacing: 0) {
                    ForEach(Array(related.enumerated()), id: \.element.id) { index, other in
                        NavigationLink(value: other) {
                            MetricRow(metric: other)
                        }
                        .buttonStyle(PressableCardStyle())
                        if index < related.count - 1 {
                            Divider().overlay(Theme.Palette.border)
                        }
                    }
                }
            }
        }
    }
}
