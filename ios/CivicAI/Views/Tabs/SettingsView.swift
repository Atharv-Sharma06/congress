import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var store: MetricsStore
    @Environment(\.openURL) private var openURL

    @State private var isChangingLocation = false

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Location") {
                    Button {
                        Haptics.tap()
                        isChangingLocation = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(appState.selectedLocation?.displayName ?? "Not set")
                                    .foregroundStyle(Theme.Palette.foreground)
                                Text("Tap to change your county")
                                    .font(.caption)
                                    .foregroundStyle(Theme.Palette.foregroundMuted)
                            }
                            Spacer(minLength: Theme.Space.sm)
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Theme.Palette.foregroundMuted)
                        }
                        .frame(minHeight: Theme.minTapTarget)
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Change location. Currently \(appState.selectedLocation?.displayName ?? "not set").")
                    .glassListRow()
                }

                Section {
                    ForEach(DataProvider.all) { provider in
                        Button {
                            if let url = URL(string: provider.url) { openURL(url) }
                        } label: {
                            HStack(alignment: .top, spacing: Theme.Space.md) {
                                Image(systemName: provider.sfSymbol)
                                    .foregroundStyle(Theme.Palette.primary)
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.name)
                                        .foregroundStyle(Theme.Palette.foreground)
                                    Text(provider.detail)
                                        .font(.caption)
                                        .foregroundStyle(Theme.Palette.foregroundMuted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: Theme.Space.sm)
                                Image(systemName: "arrow.up.right.square")
                                    .font(.footnote)
                                    .foregroundStyle(Theme.Palette.foregroundMuted)
                            }
                            .frame(minHeight: Theme.minTapTarget)
                            .contentShape(Rectangle())
                        }
                        .accessibilityLabel("\(provider.name). \(provider.detail). Opens in Safari.")
                        .glassListRow()
                    }
                } header: {
                    Text("Where the data comes from")
                } footer: {
                    Text("CivicAI reads published federal datasets. It does not create, estimate or adjust any statistic. Dollar figures are reported in the dollars of their own year and are not adjusted for inflation.")
                }

                Section {
                    NavigationLink("How CivicAI answers questions") { AboutAIView() }
                        .frame(minHeight: Theme.minTapTarget)
                        .glassListRow()
                } header: {
                    Text("About")
                } footer: {
                    Text("CivicAI \(version)")
                }

                Section {
                    Button(role: .destructive) {
                        appState.selectedLocation = nil
                        appState.comparisonLocation = nil
                        store.clear()
                    } label: {
                        Text("Reset saved location")
                            .frame(minHeight: Theme.minTapTarget)
                    }
                    .glassListRow()
                } footer: {
                    Text("Your county is the only thing CivicAI stores, and it stays on this device.")
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Settings")
            .sheet(isPresented: $isChangingLocation) {
                LocationPickerView(isDismissable: true) { county in
                    appState.selectedLocation = county
                    store.reload(for: county)
                }
            }
        }
    }
}

private struct DataProvider: Identifiable {
    let id: String
    let name: String
    let detail: String
    let url: String
    let sfSymbol: String

    static let all: [DataProvider] = [
        .init(
            id: "census",
            name: "U.S. Census Bureau",
            detail: "American Community Survey 5-year estimates — population, income, housing, education.",
            url: "https://www.census.gov/programs-surveys/acs",
            sfSymbol: "building.columns"
        ),
        .init(
            id: "bls",
            name: "Bureau of Labor Statistics",
            detail: "Local Area Unemployment Statistics — unemployment rate and labor force, via FRED.",
            url: "https://www.bls.gov/lau/",
            sfSymbol: "briefcase"
        ),
        .init(
            id: "bea",
            name: "Bureau of Economic Analysis",
            detail: "Per capita personal income by county, via FRED.",
            url: "https://www.bea.gov/data/income-saving/personal-income-county-metro-and-other-areas",
            sfSymbol: "banknote"
        ),
        .init(
            id: "fred",
            name: "FRED, St. Louis Fed",
            detail: "The distribution service CivicAI reads BLS and BEA county series from.",
            url: "https://fred.stlouisfed.org",
            sfSymbol: "chart.line.uptrend.xyaxis"
        ),
    ]
}

private struct AboutAIView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xl) {
                block(
                    "It reads data, not the internet",
                    "When you ask a question, CivicAI sends only your county's loaded datasets to the model. The model cannot look anything up and is instructed to answer strictly from those numbers."
                )
                block(
                    "Sources are built from the data, not the answer",
                    "The source list under every answer is assembled from the datasets that were actually used. If the model names a dataset that isn't in your county's data, it is discarded before you see it."
                )
                block(
                    "It describes, it doesn't explain why",
                    "CivicAI reports what changed and over what period. It does not claim one thing caused another, and it does not take a position on policy."
                )
                block(
                    "When it doesn't know",
                    "If your county's datasets can't answer the question, CivicAI says so rather than guessing."
                )
                block(
                    "Estimates have error bars",
                    "American Community Survey values are survey estimates, not counts. In smaller counties the margin of error can be wide — treat small year-to-year moves with care."
                )
            }
            .padding(Theme.Space.lg)
        }
        .appBackground()
        .navigationTitle("How it works")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func block(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.sm) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.Palette.foreground)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(body)
                .font(.body)
                .foregroundStyle(Theme.Palette.foregroundMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
