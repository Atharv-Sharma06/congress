import CoreLocation
import Foundation

/// Wraps CoreLocation + reverse geocoding into one `await`-able call.
/// We only ever ask for a coarse, one-shot fix — no background tracking, no history.
@MainActor
final class LocationService: NSObject, ObservableObject {

    enum Failure: LocalizedError {
        case denied
        case unavailable
        case noCounty

        var errorDescription: String? {
            switch self {
            case .denied:
                return "Location access is off. You can turn it on in Settings, or pick your county from the list."
            case .unavailable:
                return "We couldn't determine your location. Please pick your county from the list."
            case .noCounty:
                return "We found your location but not its county. Please pick your county from the list."
            }
        }
    }

    @Published private(set) var isLocating = false

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var isDenied: Bool {
        manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    }

    /// Returns the (state abbreviation, county name) the backend can resolve to a FIPS pair.
    func detectCounty() async throws -> (state: String, county: String) {
        isLocating = true
        defer { isLocating = false }

        if isDenied { throw Failure.denied }

        let location = try await requestFix()
        let places = try? await CLGeocoder().reverseGeocodeLocation(location)
        guard let place = places?.first else { throw Failure.unavailable }

        // `subAdministrativeArea` is the county; `administrativeArea` is the state code.
        guard let state = place.administrativeArea, !state.isEmpty else { throw Failure.unavailable }
        guard let county = place.subAdministrativeArea ?? place.locality, !county.isEmpty else {
            throw Failure.noCounty
        }
        return (state, county)
    }

    private func requestFix() async throws -> CLLocation {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            if manager.authorizationStatus == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
        }
    }

    private func finish(with result: Result<CLLocation, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.requestLocation()
            case .denied, .restricted:
                finish(with: .failure(Failure.denied))
            case .notDetermined:
                break
            @unknown default:
                finish(with: .failure(Failure.unavailable))
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in finish(with: .success(location)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in finish(with: .failure(Failure.unavailable)) }
    }
}
