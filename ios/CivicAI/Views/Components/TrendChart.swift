import Accessibility
import Charts
import SwiftUI

/// Interactive 10-year trend line. Scrubbing is optional — every value is also
/// reachable through the accessibility rotor.
///
/// The series is always `accent` orange rather than a per-metric sentiment color.
/// Sentiment lives in the trend pill and its arrow; keeping it out of the chart
/// means the eye reads shape first and never has to decode a hue.
struct TrendChart: View {
    let history: [DataPoint]
    let format: MetricFormat
    let metricName: String
    var lineColor: Color = Theme.Palette.accent
    var interactive: Bool = true
    var height: CGFloat = 200

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedYear: Int?

    private var selected: DataPoint? {
        guard let selectedYear else { return nil }
        return history.min { abs($0.year - selectedYear) < abs($1.year - selectedYear) }
    }

    private var yRange: ClosedRange<Double> {
        let values = history.map(\.value)
        guard let low = values.min(), let high = values.max() else { return 0...1 }
        // A flat-looking series is honest; a 10% pad keeps the line off the frame edges.
        let pad = max((high - low) * 0.15, high == low ? max(abs(high) * 0.05, 1) : 0)
        return (low - pad)...(high + pad)
    }

    var body: some View {
        if history.count < 2 {
            StatusView(
                symbol: "chart.line.flattrend.xyaxis",
                title: "Not enough history",
                message: "Only one year of \(metricName.lowercased()) has been published for this county."
            )
            .frame(height: height)
        } else {
            chart
        }
    }

    private var chart: some View {
        Chart {
            ForEach(history) { point in
                AreaMark(
                    x: .value("Year", point.year),
                    yStart: .value("Floor", yRange.lowerBound),
                    yEnd: .value(metricName, point.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [lineColor.opacity(0.28), lineColor.opacity(0.02)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Year", point.year),
                    y: .value(metricName, point.value)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .interpolationMethod(.monotone)
            }

            if let selected {
                RuleMark(x: .value("Year", selected.year))
                    .foregroundStyle(Theme.Palette.foregroundMuted.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                PointMark(
                    x: .value("Year", selected.year),
                    y: .value(metricName, selected.value)
                )
                .foregroundStyle(lineColor)
                .symbolSize(120)
                .annotation(position: .top, spacing: Theme.Space.sm, overflowResolution: .init(x: .fit, y: .disabled)) {
                    calloutBubble(for: selected)
                }
            }
        }
        .chartYScale(domain: yRange)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                    .foregroundStyle(Theme.Palette.gridline)
                AxisValueLabel {
                    if let raw = value.as(Double.self) {
                        Text(Format.compact(raw, as: format))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(Theme.Palette.foregroundMuted)
                    }
                }
            }
        }
        .chartXAxis {
            // Auto-skipping keeps year labels legible at 375pt and at large text sizes.
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisValueLabel {
                    if let year = value.as(Int.self) {
                        Text(String(year))
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(Theme.Palette.foregroundMuted)
                    }
                }
            }
        }
        .chartXSelection(value: interactive ? $selectedYear : .constant(nil))
        .frame(height: height)
        // Draws itself in left to right, once. With Reduce Motion on the mask is
        // full width from the first frame, so the data is legible immediately.
        .drawsIn()
        .animation(reduceMotion ? nil : Theme.Motion.standard, value: history)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(metricName) from \(history.first!.year) to \(history.last!.year)")
        .accessibilityChartDescriptor(self)
    }

    private func calloutBubble(for point: DataPoint) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(String(point.year))
                .font(.caption2)
                .foregroundStyle(Theme.Palette.foregroundMuted)
            Text(Format.value(point.value, as: format))
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.Palette.foreground)
        }
        .padding(.horizontal, Theme.Space.sm)
        .padding(.vertical, Theme.Space.xs)
        .background(Theme.Palette.surfaceElevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.Palette.border))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    }
}

/// Makes every data point reachable with the VoiceOver rotor, so the chart is not
/// a dead end for screen reader users.
extension TrendChart: AXChartDescriptorRepresentable {
    func makeChartDescriptor() -> AXChartDescriptor {
        let years = history.map { Double($0.year) }
        let values = history.map(\.value)

        let xAxis = AXNumericDataAxisDescriptor(
            title: "Year",
            range: (years.min() ?? 0)...(years.max() ?? 1),
            gridlinePositions: []
        ) { "\(Int($0))" }

        let yAxis = AXNumericDataAxisDescriptor(
            title: metricName,
            range: (values.min() ?? 0)...(values.max() ?? 1),
            gridlinePositions: []
        ) { Format.value($0, as: format) }

        let series = AXDataSeriesDescriptor(
            name: metricName,
            isContinuous: true,
            dataPoints: history.map {
                AXDataPoint(x: Double($0.year), y: $0.value, additionalValues: [], label: nil)
            }
        )

        return AXChartDescriptor(
            title: metricName,
            summary: nil,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

/// Compact inline version used inside metric cards on the dashboard.
struct Sparkline: View {
    let history: [DataPoint]
    var color: Color = Theme.Palette.accent

    var body: some View {
        Chart(history) { point in
            AreaMark(x: .value("Year", point.year), y: .value("Value", point.value))
                .foregroundStyle(
                    .linearGradient(
                        colors: [color.opacity(0.22), color.opacity(0.0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

            LineMark(x: .value("Year", point.year), y: .value("Value", point.value))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .interpolationMethod(.monotone)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: .automatic(includesZero: false))
        .frame(height: 40)
        .drawsIn()
        .accessibilityHidden(true)   // The card already states the value and trend.
    }
}
