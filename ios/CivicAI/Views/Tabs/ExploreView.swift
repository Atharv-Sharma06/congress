import SwiftUI

/// Browse every measure by category. Same data the dashboard uses — no second fetch.
struct ExploreView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: MetricsStore

    @State private var query = ""

    var body: some View {
        NavigationStack {
            Group {
                switch store.state {
                case .idle, .loading:
                    loadingSkeleton
                case .failed(let error):
                    StatusView.error(error) {
                        if let location = appState.selectedLocation { store.reload(for: location) }
                    }
                case .loaded(let bundle):
                    loaded(bundle)
                }
            }
            .appBackground()
            .navigationTitle("Explore")
            .navigationDestination(for: Metric.self) { MetricDetailView(metric: $0) }
        }
        .task(id: appState.selectedLocation?.id) {
            guard let location = appState.selectedLocation else { return }
            store.loadIfNeeded(for: location)
        }
    }

    private var loadingSkeleton: some View {
        ScrollView {
            VStack(spacing: Theme.Space.md) {
                ForEach(0..<6, id: \.self) { _ in
                    CardSurface {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            SkeletonBlock(height: 16, width: 120)
                            SkeletonBlock(height: 12, width: 200)
                        }
                    }
                }
            }
            .padding(Theme.Space.lg)
        }
    }

    private func loaded(_ bundle: MetricsBundle) -> some View {
        List {
            if filtered(bundle).isEmpty {
                Section {
                    StatusView(
                        symbol: "magnifyingglass",
                        title: "Nothing matches “\(query)”",
                        message: "Try a broader word like “income”, “rent”, or “school”."
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                ForEach(bundle.categories) { category in
                    let metrics = filtered(bundle).filter { $0.category == category.id }
                    if !metrics.isEmpty {
                        Section {
                            ForEach(metrics) { metric in
                                NavigationLink(value: metric) { MetricRow(metric: metric) }
                                    .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                                    .glassListRow()
                            }
                        } header: {
                            Label(category.name, systemImage: category.sfSymbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.Palette.foregroundMuted)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
        .searchable(text: $query, prompt: "Search measures")
        .refreshable {
            if let location = appState.selectedLocation { store.reload(for: location) }
        }
    }

    private func filtered(_ bundle: MetricsBundle) -> [Metric] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return bundle.metrics }
        return bundle.metrics.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.definition.localizedCaseInsensitiveContains(trimmed)
                || $0.category.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
