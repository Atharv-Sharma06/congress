import SwiftUI

/// The dashboard. Headline metrics above the fold, everything else below,
/// and one prominent CTA docked at the bottom.
struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: MetricsStore

    @State private var isAsking = false

    private let columns = [
        GridItem(.flexible(), spacing: Theme.Space.md),
        GridItem(.flexible(), spacing: Theme.Space.md),
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                AppBackground()
                content
                askBar
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Metric.self) { MetricDetailView(metric: $0) }
            .sheet(isPresented: $isAsking) {
                if let location = appState.selectedLocation {
                    AskCivicAIView(location: location)
                }
            }
        }
        .task(id: appState.selectedLocation?.id) {
            guard let location = appState.selectedLocation else { return }
            store.loadIfNeeded(for: location)
        }
    }

    // MARK: - Content states

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .idle, .loading:
            loadingSkeleton
        case .failed(let error):
            ScrollView {
                StatusView.error(error) {
                    if let location = appState.selectedLocation { store.reload(for: location) }
                }
                .padding(.top, Theme.Space.xxl)
            }
        case .loaded(let bundle):
            loaded(bundle)
        }
    }

    private var loadingSkeleton: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.lg) {
                header(title: appState.selectedLocation?.displayName ?? "Loading…")
                LazyVGrid(columns: columns, spacing: Theme.Space.md) {
                    ForEach(0..<4, id: \.self) { _ in MetricCardSkeleton() }
                }
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.top, Theme.Space.sm)
        }
        .accessibilityLabel("Loading community data")
    }

    private func loaded(_ bundle: MetricsBundle) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                header(title: bundle.location.displayName)

                LazyVGrid(columns: columns, spacing: Theme.Space.md) {
                    ForEach(Array(bundle.headlineMetrics.enumerated()), id: \.element.id) { index, metric in
                        NavigationLink(value: metric) { MetricCard(metric: metric) }
                            .buttonStyle(PressableCardStyle())
                            .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                            .staggeredAppear(index: index)
                    }
                }

                ForEach(Array(bundle.categories.enumerated()), id: \.element.id) { categoryIndex, category in
                    let metrics = bundle.metrics(in: category.id).filter { !bundle.headline.contains($0.id) }
                    if !metrics.isEmpty {
                        VStack(alignment: .leading, spacing: Theme.Space.sm) {
                            Label(category.name, systemImage: category.sfSymbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Theme.Palette.foreground)
                                .accessibilityAddTraits(.isHeader)

                            CardSurface(padding: Theme.Space.md) {
                                VStack(spacing: 0) {
                                    ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                                        NavigationLink(value: metric) { MetricRow(metric: metric) }
                                            .buttonStyle(PressableCardStyle())
                                            .simultaneousGesture(TapGesture().onEnded { Haptics.tap() })
                                        if index < metrics.count - 1 {
                                            Divider().overlay(Theme.Palette.border)
                                        }
                                    }
                                }
                            }
                        }
                        // Sections continue the dashboard's reveal rhythm, offset past
                        // the four headline cards.
                        .staggeredAppear(index: categoryIndex + 4)
                    }
                }

                Text("Data from the U.S. Census Bureau, Bureau of Labor Statistics and Bureau of Economic Analysis. Tap any measure to see its source.")
                    .font(.caption)
                    .foregroundStyle(Theme.Palette.foregroundMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, Theme.Space.lg)
            .padding(.top, Theme.Space.sm)
            // Clears the docked Ask bar so the last card is never hidden behind it.
            .padding(.bottom, 96)
        }
        .refreshable {
            if let location = appState.selectedLocation { store.reload(for: location) }
        }
    }

    private func header(title: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Theme.Palette.foreground)
                .fixedSize(horizontal: false, vertical: true)
            Text("Here's what's changing in your community.")
                .font(.subheadline)
                .foregroundStyle(Theme.Palette.foregroundMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Ask CTA

    private var askBar: some View {
        Button {
            Haptics.tap()
            isAsking = true
        } label: {
            HStack(spacing: Theme.Space.sm) {
                Image(systemName: "sparkle.magnifyingglass")
                Text("Ask CivicAI")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, Theme.Space.lg)
        .padding(.vertical, Theme.Space.md)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { Divider().overlay(Theme.Palette.border) }
        .accessibilityLabel("Ask CivicAI a question about this county")
        .disabled(appState.selectedLocation == nil)
    }
}
