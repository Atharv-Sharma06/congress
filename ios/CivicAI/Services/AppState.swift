import Foundation
import SwiftUI

/// App-wide state: the selected county, persisted across launches.
/// Deliberately the only thing we store about the user.
@MainActor
final class AppState: ObservableObject {
    private static let storageKey = "civicai.selectedLocation.v1"

    @Published var selectedLocation: CountyLocation? {
        didSet { persist() }
    }

    /// Second location for Compare. Not persisted — it's a per-session exploration.
    @Published var comparisonLocation: CountyLocation?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(CountyLocation.self, from: data) {
            selectedLocation = saved
        }
    }

    private func persist() {
        guard let selectedLocation else {
            UserDefaults.standard.removeObject(forKey: Self.storageKey)
            return
        }
        if let data = try? JSONEncoder().encode(selectedLocation) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}

/// Generic screen state so every data surface handles loading, empty and error the same way.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(CivicError)

    var value: Value? {
        if case .loaded(let v) = self { return v }
        return nil
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var error: CivicError? {
        if case .failed(let e) = self { return e }
        return nil
    }
}
