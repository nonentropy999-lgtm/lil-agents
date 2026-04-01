import Foundation

// MARK: - Provider

enum AgentProvider: String, CaseIterable {
    case gemini, codex

    private static let defaultsKey = "selectedProvider"

    static var current: AgentProvider {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultsKey) ?? AgentProvider.gemini.rawValue
            return AgentProvider(rawValue: raw) ?? .gemini
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: defaultsKey)
        }
    }

    var displayName: String {
        switch self {
        case .gemini: return "Gemini"
        case .codex:  return "Codex"
        }
    }

    var inputPlaceholder: String {
        "Ask \(displayName)..."
    }

    /// Returns provider name styled per theme format.
    func titleString(format: TitleFormat) -> String {
        switch format {
        case .uppercase:      return displayName.uppercased()
        case .lowercaseTilde: return "\(displayName.lowercased()) ~"
        case .capitalized:    return displayName
        }
    }

    var installInstructions: String {
        switch self {
        case .gemini:
            return "To install, run this in Terminal:\n  npm install -g @google/gemini-cli\n\nThen authenticate:\n  gemini auth"
        case .codex:
            return "To install, run this in Terminal:\n  npm install -g @openai/codex"
        }
    }

    func createSession() -> any AgentSession {
        switch self {
        case .gemini: return GeminiSession()
        case .codex:  return CodexSession()
        }
    }
}

// MARK: - Title Format

enum TitleFormat {
    case uppercase       // "CLAUDE"
    case lowercaseTilde  // "claude ~"
    case capitalized     // "Gemini"
}

// MARK: - Message

struct AgentMessage {
    enum Role { case user, assistant, error, toolUse, toolResult }
    let role: Role
    let text: String
}

// MARK: - Session Protocol

protocol AgentSession: AnyObject {
    var isRunning: Bool { get }
    var isBusy: Bool { get }
    var history: [AgentMessage] { get set }

    var onText: ((String) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    var onToolUse: ((String, [String: Any]) -> Void)? { get set }
    var onToolResult: ((String, Bool) -> Void)? { get set }
    var onSessionReady: (() -> Void)? { get set }
    var onTurnComplete: (() -> Void)? { get set }
    var onProcessExit: (() -> Void)? { get set }

    func start()
    func send(message: String)
    func terminate()
}
