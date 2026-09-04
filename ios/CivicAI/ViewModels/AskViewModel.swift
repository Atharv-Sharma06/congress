import Foundation

@MainActor
final class AskViewModel: ObservableObject {
    @Published var question: String = ""
    @Published private(set) var state: LoadState<AskResponse> = .idle

    /// Shown as tappable chips before the first question — a blank input is a dead end.
    let suggestions = [
        "How has housing changed over 10 years?",
        "Is this county getting younger or older?",
        "What happened to jobs here since 2015?",
        "How do incomes compare to housing costs?",
    ]

    private var task: Task<Void, Never>?
    private var lastLocation: CountyLocation?

    var canSubmit: Bool {
        question.trimmingCharacters(in: .whitespacesAndNewlines).count >= 3 && !state.isLoading
    }

    func submit(in location: CountyLocation) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return }
        lastLocation = location
        run(trimmed, location)
    }

    func retry() {
        guard let lastLocation else { return }
        run(question.trimmingCharacters(in: .whitespacesAndNewlines), lastLocation)
    }

    func reset() {
        task?.cancel()
        question = ""
        state = .idle
    }

    private func run(_ question: String, _ location: CountyLocation) {
        task?.cancel()
        state = .loading
        task = Task { [weak self] in
            do {
                let response = try await APIClient.shared.ask(question, in: location)
                guard !Task.isCancelled else { return }
                self?.state = .loaded(response)
                Haptics.success()
            } catch is CancellationError {
                return
            } catch let error as CivicError {
                guard !Task.isCancelled else { return }
                self?.state = .failed(error)
            } catch {
                guard !Task.isCancelled else { return }
                self?.state = .failed(.aiUnavailable)
            }
        }
    }
}
