import Foundation

enum GeminiModel: String, CaseIterable {
    case flashPreview = "gemini-3-flash-preview"
    case proPreview = "gemini-3-pro-preview"

    var displayName: String {
        switch self {
        case .flashPreview:
            return "Gemini 3 Flash Preview"
        case .proPreview:
            return "Gemini 3 Pro Preview"
        }
    }
}

enum GeminiModelSettings {
    private static let defaultsKey = "geminiModel"

    static var current: GeminiModel {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? GeminiModel.proPreview.rawValue
            return GeminiModel(rawValue: raw) ?? .proPreview
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }
}
