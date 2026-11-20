import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case korean = "ko"
    case english = "en"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .korean: return "한국어"
        case .english: return "English"
        }
    }

    /// Returns `.korean` when the preferred system language is Korean (`ko`, `ko-KR`, `ko_KR`),
    /// and `.english` for all other languages.
    public static func defaultLanguage(preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        guard let first = preferredLanguages.first?.lowercased() else {
            return .english
        }
        if first == "ko" || first.hasPrefix("ko-") || first.hasPrefix("ko_") {
            return .korean
        }
        return .english
    }
}
