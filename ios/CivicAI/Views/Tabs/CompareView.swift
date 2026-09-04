import SwiftUI

/// Side-by-side county comparison with a neutral, sourced explanation.
struct CompareView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = CompareViewModel()

    @State private var isPickingSecond = false
    @State private var showingSources = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.xl) {
                    selectors
                    if appState.comparisonLocation == nil {
                        StatusView(
                            symbol: "arrow.left.and.right",
                            title: "Pick a second county",
                            message: "Compare \(appState.selectedLocation?.county ?? "your county") with anywhere else in the country.",
                            actionTitle: "Choose a county",
                            action: { isPickingSecond = true }
                        )
                    } else {
                        results
                    }
                }
                .padding(Theme.Space.lg)
            }
            .appBackground()
            .navigationTitle("Compare")
            .sheet(isPresented: $isPickingSecond) {
                LocationPickerView(isDismissable: true) { county in
                    appState.comparisonLocation = county
                }
            }
            .sheet(isPresented: $showingSources) {
                SourceSheet(sources: viewModel.state.value?.sources ?? [])
            }
        }
        .task(id: pairKey) {
            guard let a = appState.selectedLocation, let b = appState.comparisonLocation else { return }
            viewModel.loadIfNeeded(a, b)
        }
    }

    private var pairKey: String {
        "\(appState.selectedLocation?.id ?? "-")|\(appState.comparisonLocation?.id ?? "-")"
    }

    // MARK: - Selectors

    private var selectors: some View {
        HStack(spacing: Theme.Space.md) {
            selectorCard(
                label: "Your county",
                name: appState.selectedLocation?.county ?? "Not set",
                detail: appState.selectedLocation?.stateName ?? "",
                action: nil
            )
            Image(systemName: "arrow.left.and.right")
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.Palette.foregroundMuted)
                .accessibilityHidden(true)
            selectorCard(
                label: "Compare with",
                name: appState.comparisonLocation?.county ?? "Choose",
                detail: appState.comparisonLocation?.stateName ?? "Tap to pick",
                action: { isPickingSecond = true }
            )
        }
    }

    private func selectorCard(label: String, name: String, detail: String, action: (() -> Void)?) -> some View {
        let card = CardSurface(padding: Theme.Space.md) {
            VStack(alignment: .leading, spacing: Theme.Space.xs) {
                Text(label.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(Theme.Palette.foregroundMuted)
                Text(name)
                    .font(.headline)
                    .foregroundStyle(Theme.Palette.foreground)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.foregroundMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        }

        return Group {
            if let action {
                Button { Haptics.tap(); action() } label: { card }
                    .buttonStyle(PressableCardStyle())
                    .accessibilityLabel("\(label): \(name). Tap to change.")
            } else {
                card.accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var results: some View {
        switch viewModel.state {
        case .idle, .loading:
            VStack(spacing: Theme.Space.md) {
                ForEach(0..<4, id: \.self) { _ in
                    CardSurface {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            SkeletonBlock(height: 12, width: 110)
                            SkeletonBlock(height: 22)
                        }
                    }
                }
            }
        case .failed(let error):
            StatusView.error(error) { viewModel.retry() }
        case .loaded(let response):
            comparison(response)
        }
    }

    private func comparison(_ response: ComparisonResponse) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xl) {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                SectionHeader(title: "Side by side")
                ForEach(Array(response.comparison.enumerated()), id: \.element.id) { index, row in
                    comparisonRow(row, response).staggeredAppear(index: index)
                }
            }

            if let explanation = response.explanation {
                VStack(alignment: .leading, spacing: Theme.Space.md) {
                    SectionHeader(title: "What the data shows")
                    CardSurface {
                        VStack(alignment: .leading, spacing: Theme.Space.md) {
                            Text(explanation.summary)
                                .font(.body.weight(.medium))
                                .foregroundStyle(Theme.Palette.foreground)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(explanation.whatThisMeans)
                                .font(.body)
                                .foregroundStyle(Theme.Palette.foreground)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if !response.sources.isEmpty {
                Button {
                    Haptics.tap()
                    showingSources = true
                } label: {
                    Label("View sources (\(response.sources.count))", systemImage: "link.circle")
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private func comparisonRow(_ row: ComparisonRow, _ response: ComparisonResponse) -> some View {
        CardSurface {
            VStack(alignment: .leading, spacing: Theme.Space.md) {
                Label(row.name, systemImage: row.sfSymbol)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Palette.foregroundMuted)

                HStack(alignment: .top, spacing: Theme.Space.md) {
                    valueColumn(response.locationA.county, row.a, row.format, tint: Theme.Palette.primary)
                    Divider().frame(maxHeight: 44).overlay(Theme.Palette.border)
                    valueColumn(response.locationB.county, row.b, row.format, tint: Theme.Palette.secondary)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(row.name). \(response.locationA.county): \(Format.value(row.a.value, as: row.format)) in \(row.a.year). "
            + "\(response.locationB.county): \(Format.value(row.b.value, as: row.format)) in \(row.b.year)."
        )
    }

    private func valueColumn(_ name: String, _ value: ComparisonValue, _ format: MetricFormat, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(name)
                .font(.caption)
                .foregroundStyle(tint)
                .fixedSize(horizontal: false, vertical: true)
            Text(Format.value(value.value, as: format))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.Palette.foreground)
                .minimumScaleFactor(0.75)
            Text(String(value.year))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(Theme.Palette.foregroundMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
