import Foundation

// MARK: - Location

struct CountyLocation: Codable, Identifiable, Hashable {
    let id: String            // 5-digit FIPS, e.g. "45091"
    let stateFips: String
    let countyFips: String
    let stateAbbr: String
    let stateName: String
    let county: String        // "York County"
    let displayName: String   // "York County, South Carolina"
}

struct USState: Codable, Identifiable, Hashable {
    let fips: String
    let abbr: String
    let name: String
    var id: String { fips }
}

// MARK: - Metrics

enum TrendDirection: String, Codable { case up, down, stable }

/// Whether the movement is good, bad, or simply neutral for this county.
/// Separated from direction because "home values up" is not inherently good or bad.
enum TrendSentiment: String, Codable { case positive, negative, neutral }

struct Trend: Codable, Hashable {
    let direction: TrendDirection
    let sentiment: TrendSentiment
}

enum MetricFormat: String, Codable {
    case currency, percent, integer

    /// Unknown formats from a future backend degrade to a plain number rather than crashing.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = MetricFormat(rawValue: raw) ?? .integer
    }
}

struct DataPoint: Codable, Hashable, Identifiable {
    let year: Int
    let value: Double
    var id: Int { year }
}

struct MetricChange: Codable, Hashable {
    let fromYear: Int
    let toYear: Int
    let fromValue: Double
    let toValue: Double
    let absoluteChange: Double
    let percentChange: Double?

    var spanYears: Int { toYear - fromYear }
}

struct Source: Codable, Hashable, Identifiable {
    let name: String
    let organization: String
    let url: String
    let lastUpdated: String?
    let methodology: String?
    var metricId: String?
    var metricName: String?

    var id: String { "\(organization)-\(name)" }
    var webURL: URL? { URL(string: url) }
}

struct Metric: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let category: String
    let unit: String
    let format: MetricFormat
    let definition: String
    let sfSymbol: String
    let currentValue: Double
    let currentYear: Int
    let trend: Trend
    let changeFiveYear: MetricChange?
    let changeTenYear: MetricChange?
    let history: [DataPoint]
    let source: Source

    /// Prefers the 5-year window, falling back to 10 when a county has sparse history.
    var headlineChange: MetricChange? { changeFiveYear ?? changeTenYear }
}

struct MetricCategory: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let sfSymbol: String
}

struct MetricsBundle: Codable {
    let location: CountyLocation
    let generatedAt: String
    let headline: [String]
    let categories: [MetricCategory]
    let metrics: [Metric]

    func metric(id: String) -> Metric? { metrics.first { $0.id == id } }
    var headlineMetrics: [Metric] { headline.compactMap(metric(id:)) }
    func metrics(in category: String) -> [Metric] { metrics.filter { $0.category == category } }
}

struct RelatedMetric: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let sfSymbol: String
}

struct MetricDetail: Codable {
    let location: CountyLocation
    let metric: Metric
    let related: [RelatedMetric]
}

// MARK: - Ask

struct KeyFinding: Codable, Identifiable, Hashable {
    let sfSymbol: String
    let title: String
    let value: String
    let change: String
    let metricId: String?
    var id: String { title + value }
}

struct AskChart: Codable, Hashable {
    let metricId: String
    let name: String
    let unit: String
    let format: MetricFormat
    let history: [DataPoint]
}

struct AskResponse: Codable {
    let question: String
    let location: CountyLocation
    let dataAvailable: Bool
    let summary: String
    let keyFindings: [KeyFinding]
    let whatThisMeans: String
    let chart: AskChart?
    let sources: [Source]
    let generatedAt: String
}

// MARK: - Compare

struct ComparisonValue: Codable, Hashable {
    let value: Double
    let year: Int
}

struct ComparisonRow: Codable, Identifiable, Hashable {
    let metricId: String
    let name: String
    let category: String
    let unit: String
    let format: MetricFormat
    let sfSymbol: String
    let a: ComparisonValue
    let b: ComparisonValue
    let definition: String
    var id: String { metricId }
}

struct ComparisonExplanation: Codable, Hashable {
    let summary: String
    let whatThisMeans: String
}

struct ComparisonResponse: Codable {
    let locationA: CountyLocation
    let locationB: CountyLocation
    let comparison: [ComparisonRow]
    let explanation: ComparisonExplanation?
    let sources: [Source]
    let generatedAt: String
}

// MARK: - Errors

struct APIErrorBody: Codable {
    struct Payload: Codable {
        let code: String
        let message: String
    }
    let error: Payload
}

/// Every case carries a message that is already safe to show a user.
/// Upstream/provider text is logged on the server and never reaches here.
enum CivicError: LocalizedError, Equatable {
    case offline
    case timedOut
    case rateLimited
    case notFound(String)
    case aiUnavailable
    case server(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .offline:          return "Network error. Please check your connection."
        case .timedOut:         return "That took too long. Please try again."
        case .rateLimited:      return "Too many requests. Please wait a moment before trying again."
        case .notFound(let m):  return m
        case .aiUnavailable:    return "Unable to analyze that question right now."
        case .server(let m):    return m
        case .decoding:         return "We couldn't read the response from CivicAI."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .notFound: return false
        default: return true
        }
    }
}
