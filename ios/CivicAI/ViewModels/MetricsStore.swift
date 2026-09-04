import Foundation

/// Loads the county's metric bundle once and shares it with Home and Explore,
/// so switching tabs never refetches or re-renders from scratch.
@MainActor
final class MetricsStore: ObservableObject {
    @Published private(set) var state: LoadState<MetricsBundle> = .idle

    private var loadedLocationID: String?
    private var task: Task<Void, Never>?

    var bundle: MetricsBundle? { state.value }

    /// Loads if this is a new county or nothing is loaded yet. Cheap to call from `.task`.
    func loadIfNeeded(for location: CountyLocation) {
        guard loadedLocationID != location.id || state.value == nil else { return }
        load(location)
    }

    func reload(for location: CountyLocation) {
        load(location)
    }

    private func load(_ location: CountyLocation) {
        task?.cancel()
        loadedLocationID = location.id
        state = .loading

        task = Task { [weak self] in
            do {
                let bundle = try await APIClient.shared.metrics(for: location)
                guard !Task.isCancelled else { return }
                self?.state = .loaded(bundle)
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

    func clear() {
        task?.cancel()
        loadedLocationID = nil
        state = .idle
    }
}
