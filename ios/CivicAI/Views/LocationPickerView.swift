import SwiftUI

/// First run and "change location". Search, browse by state, or detect —
/// three ways in, because location permission is never assumed.
struct LocationPickerView: View {
    /// When presented as a sheet from Settings we show a Cancel button; on first
    /// launch there is nothing to go back to, so we don't.
    var isDismissable: Bool = false
    var onSelect: (CountyLocation) -> Void

    @StateObject private var viewModel = LocationPickerViewModel()
    @StateObject private var locationService = LocationService()
    @Environment(\.dismiss) private var dismiss

    @State private var detectError: String?
    @State private var isDetecting = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isSearching {
                    searchResults
                } else {
                    stateList
                }
            }
            .appBackground()
            .navigationTitle("Choose your county")
            .navigationBarTitleDisplayMode(.large)
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search counties"
            )
            .toolbar {
                if isDismissable {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .task { await viewModel.loadStates() }
            .alert("Location", isPresented: Binding(get: { detectError != nil }, set: { if !$0 { detectError = nil } })) {
                Button("OK") { detectError = nil }
            } message: {
                Text(detectError ?? "")
            }
        }
    }

    // MARK: - Browse by state

    private var stateList: some View {
        List {
            Section {
                Button(action: detect) {
                    HStack(spacing: Theme.Space.md) {
                        Image(systemName: "location.fill")
                            .foregroundStyle(Theme.Palette.primary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Detect my county")
                                .foregroundStyle(Theme.Palette.foreground)
                            Text("Uses your location once. Nothing is stored or shared.")
                                .font(.caption)
                                .foregroundStyle(Theme.Palette.foregroundMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: Theme.Space.sm)
                        if isDetecting { ProgressView() }
                    }
                    .frame(minHeight: Theme.minTapTarget)
                    .contentShape(Rectangle())
                }
                .disabled(isDetecting)
                .accessibilityLabel("Detect my county using location services")
                .glassListRow()
            }

            Section("Or browse by state") {
                if viewModel.states.isEmpty && viewModel.isLoading {
                    ForEach(0..<8, id: \.self) { _ in
                        SkeletonBlock(height: 18, width: 160).padding(.vertical, Theme.Space.sm)
                    }
                } else if let message = viewModel.errorMessage, viewModel.states.isEmpty {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(Theme.Palette.foregroundMuted)
                } else {
                    ForEach(viewModel.states) { state in
                        NavigationLink(state.name) {
                            CountyListView(state: state, viewModel: viewModel, onSelect: select)
                        }
                        .frame(minHeight: Theme.minTapTarget)
                        .glassListRow()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .appBackground()
    }

    // MARK: - Search

    @ViewBuilder
    private var searchResults: some View {
        if viewModel.searchResults.isEmpty {
            StatusView(
                symbol: "magnifyingglass",
                title: "No counties match “\(viewModel.searchText)”",
                message: "Try the county name without “County”, or browse by state."
            )
            .frame(maxHeight: .infinity)
        } else {
            List(viewModel.searchResults) { county in
                Button { select(county) } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(county.county).foregroundStyle(Theme.Palette.foreground)
                        Text(county.stateName)
                            .font(.caption)
                            .foregroundStyle(Theme.Palette.foregroundMuted)
                    }
                    .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("\(county.county), \(county.stateName)")
                .glassListRow()
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .appBackground()
        }
    }

    // MARK: - Actions

    private func select(_ county: CountyLocation) {
        Haptics.tap()
        onSelect(county)
        if isDismissable { dismiss() }
    }

    private func detect() {
        isDetecting = true
        Task {
            defer { isDetecting = false }
            do {
                let place = try await locationService.detectCounty()
                let county = try await APIClient.shared.resolve(state: place.state, county: place.county)
                select(county)
            } catch let error as LocationService.Failure {
                detectError = error.errorDescription
            } catch let error as CivicError {
                detectError = error.errorDescription
            } catch {
                detectError = "We couldn't determine your county. Please pick it from the list."
            }
        }
    }
}

/// Counties within one state.
private struct CountyListView: View {
    let state: USState
    @ObservedObject var viewModel: LocationPickerViewModel
    let onSelect: (CountyLocation) -> Void

    var body: some View {
        Group {
            if viewModel.counties.isEmpty && viewModel.isLoading {
                List(0..<10, id: \.self) { _ in
                    SkeletonBlock(height: 18, width: 180)
                        .padding(.vertical, Theme.Space.sm)
                        .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            } else if viewModel.counties.isEmpty {
                StatusView(
                    symbol: "exclamationmark.triangle",
                    title: "Couldn't load counties",
                    message: viewModel.errorMessage ?? "Please check your connection and try again.",
                    actionTitle: "Try again",
                    action: { Task { await viewModel.loadCounties(in: state) } }
                )
            } else {
                List(viewModel.counties) { county in
                    Button { onSelect(county) } label: {
                        Text(county.county)
                            .foregroundStyle(Theme.Palette.foreground)
                            .frame(maxWidth: .infinity, minHeight: Theme.minTapTarget, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .glassListRow()
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .appBackground()
        .navigationTitle(state.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadCounties(in: state) }
    }
}
