import Foundation

/// Talks to the CivicAI backend. The app holds no data-provider or OpenAI keys —
/// only the backend base URL and an optional app secret, both injected at build time.
actor APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let appKey: String?
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let info = Bundle.main.infoDictionary
        let raw = (info?["CIVICAI_API_BASE_URL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard let url = URL(string: raw), url.scheme == "https" || url.host == "localhost" else {
            fatalError(
                """
                CIVICAI_API_BASE_URL is missing or is not HTTPS.
                Set it in Config/Debug.xcconfig and Config/Release.xcconfig — see ios/README.md.
                """
            )
        }
        baseURL = url

        let key = (info?["CIVICAI_APP_KEY"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        appKey = (key?.isEmpty == false) ? key : nil

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 40
        configuration.waitsForConnectivity = false
        // 24h metric caching happens server-side; this layer just avoids duplicate
        // round trips while the user moves between tabs.
        configuration.requestCachePolicy = .useProtocolCachePolicy
        configuration.urlCache = URLCache(memoryCapacity: 8 << 20, diskCapacity: 64 << 20)
        session = URLSession(configuration: configuration)

        decoder = JSONDecoder()
    }

    // MARK: - Endpoints

    func states() async throws -> [USState] {
        struct Response: Codable { let states: [USState] }
        return try await get("/api/locations", as: Response.self).states
    }

    func counties(inState state: String) async throws -> [CountyLocation] {
        struct Response: Codable { let counties: [CountyLocation] }
        return try await get("/api/locations", query: [.init(name: "state", value: state)], as: Response.self).counties
    }

    func searchCounties(_ query: String) async throws -> [CountyLocation] {
        struct Response: Codable { let counties: [CountyLocation] }
        return try await get("/api/locations", query: [.init(name: "q", value: query)], as: Response.self).counties
    }

    /// Turns a reverse-geocoded place name into a county the backend can query.
    func resolve(state: String, county: String) async throws -> CountyLocation {
        struct Response: Codable { let location: CountyLocation }
        return try await get(
            "/api/locations/resolve",
            query: [.init(name: "state", value: state), .init(name: "county", value: county)],
            as: Response.self
        ).location
    }

    func metrics(for location: CountyLocation) async throws -> MetricsBundle {
        try await get("/api/metrics/\(location.stateFips)/\(location.countyFips)", as: MetricsBundle.self)
    }

    func metric(_ id: String, for location: CountyLocation) async throws -> MetricDetail {
        try await get("/api/metric/\(location.stateFips)/\(location.countyFips)/\(id)", as: MetricDetail.self)
    }

    func ask(_ question: String, in location: CountyLocation) async throws -> AskResponse {
        try await post(
            "/api/ask",
            body: ["question": question, "state": location.stateFips, "county": location.countyFips],
            as: AskResponse.self
        )
    }

    func compare(_ a: CountyLocation, _ b: CountyLocation) async throws -> ComparisonResponse {
        try await get(
            "/api/compare",
            query: [
                .init(name: "state1", value: a.stateFips), .init(name: "county1", value: a.countyFips),
                .init(name: "state2", value: b.stateFips), .init(name: "county2", value: b.countyFips),
            ],
            as: ComparisonResponse.self
        )
    }

    // MARK: - Transport

    private func get<T: Decodable>(_ path: String, query: [URLQueryItem] = [], as type: T.Type) async throws -> T {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        return try await send(request, as: type)
    }

    private func post<T: Decodable>(_ path: String, body: [String: String], as type: T.Type) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await send(request, as: type)
    }

    private func send<T: Decodable>(_ request: URLRequest, as type: T.Type) async throws -> T {
        var request = request
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let appKey { request.setValue(appKey, forHTTPHeaderField: "x-civicai-key") }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed:
                throw CivicError.offline
            case .timedOut:
                throw CivicError.timedOut
            default:
                throw CivicError.server("We couldn't reach CivicAI. Please try again.")
            }
        }

        guard let http = response as? HTTPURLResponse else { throw CivicError.decoding }

        guard (200..<300).contains(http.statusCode) else {
            throw Self.mapError(status: http.statusCode, data: data)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            #if DEBUG
            print("[APIClient] decoding \(T.self) failed: \(error)")
            #endif
            throw CivicError.decoding
        }
    }

    /// Maps the backend's typed error codes to user-safe messages.
    private static func mapError(status: Int, data: Data) -> CivicError {
        let body = try? JSONDecoder().decode(APIErrorBody.self, from: data)
        switch body?.error.code {
        case "RATE_LIMIT":                       return .rateLimited
        case "AI_UNAVAILABLE":                   return .aiUnavailable
        case "UNKNOWN_STATE", "UNKNOWN_COUNTY",
             "UNKNOWN_METRIC", "NO_DATA":        return .notFound(body?.error.message ?? "We don't have data for that yet.")
        default: break
        }
        switch status {
        case 429: return .rateLimited
        case 404: return .notFound(body?.error.message ?? "We don't have data for that yet.")
        case 500...599: return .server("CivicAI is having trouble right now. Please try again.")
        default: return .server(body?.error.message ?? "Something went wrong. Please try again.")
        }
    }
}
