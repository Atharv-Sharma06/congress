import Foundation

@MainActor
final class CompareViewModel: ObservableObject {
    @Published private(set) var state: LoadState<ComparisonResponse> = .idle

    private var task: Task<Void, Never>?
    private var pair: (CountyLocation, CountyLocation)?

    func loadIfNeeded(_ a: CountyLocation, _ b: CountyLocation) {
        if let pair, pair.0.id == a.id, pair.1.id == b.id, state.value != nil { return }
        load(a, b)
    }

    func retry() {
        guard let pair else { return }
        load(pair.0, pair.1)
    }

    func clear() {
        task?.cancel()
        pair = nil
        state = .idle
    }

    private func load(_ a: CountyLocation, _ b: CountyLocation) {
        task?.cancel()
        pair = (a, b)
        state = .loading
        task = Task { [weak self] in
            do {
                let response = try await APIClient.shared.compare(a, b)
                guard !Task.isCancelled else { return }
                self?.state = .loaded(response)
            } catch is CancellationError {
                return
            } catch let error as CivicError {
                guard !Task.isCancelled else { return }
                self?.state = .failed(error)
            } catch {
                guard !Task.isCancelled else { return }
                self?.state = .failed(.server("Something went wrong. Please try again."))
            }
        }
    }
}

@MainActor
final class LocationPickerViewModel: ObservableObject {
    @Published private(set) var states: [USState] = []
    @Published private(set) var counties: [CountyLocation] = []
    @Published private(set) var searchResults: [CountyLocation] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    @Published var searchText: String = "" {
        didSet { scheduleSearch() }
    }

    private var searchTask: Task<Void, Never>?

    var isSearching: Bool { searchText.trimmingCharacters(in: .whitespaces).count >= 2 }

    func loadStates() async {
        guard states.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            states = try await APIClient.shared.states()
        } catch {
            errorMessage = (error as? CivicError)?.errorDescription ?? "Couldn't load the state list."
        }
    }

    func loadCounties(in state: USState) async {
        counties = []
        isLoading = true
        defer { isLoading = false }
        do {
            counties = try await APIClient.shared.counties(inState: state.fips)
        } catch {
            errorMessage = (error as? CivicError)?.errorDescription ?? "Couldn't load counties for \(state.name)."
        }
    }

    /// Debounced so a fast typist sends one request, not one per keystroke.
    private func scheduleSearch() {
        searchTask?.cancel()
        guard isSearching else {
            searchResults = []
            return
        }
        let query = searchText
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            let results = (try? await APIClient.shared.searchCounties(query)) ?? []
            guard !Task.isCancelled else { return }
            self?.searchResults = results
        }
    }
}
