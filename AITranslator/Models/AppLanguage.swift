import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case system
    case zhHans
    case en

    var id: String { rawValue }

    var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .zhHans:
            return "zh-Hans"
        case .en:
            return "en"
        }
    }
}
