import Foundation

struct ActivitySession: Codable, Identifiable, Equatable {
    let id: UUID
    var appName: String
    var bundleIdentifier: String?
    var windowTitle: String
    var category: ActivityCategory
    var startedAt: Date
    var endedAt: Date
    var isIdle: Bool

    var duration: TimeInterval {
        max(0, endedAt.timeIntervalSince(startedAt))
    }

    var displayTitle: String {
        if isIdle { return "Відійшов від комп’ютера" }
        return windowTitle.isEmpty ? appName : windowTitle
    }
}

enum ActivityCategory: String, Codable, CaseIterable, Identifiable {
    case development = "Розробка"
    case communication = "Спілкування"
    case ai = "AI-інструменти"
    case video = "Відео"
    case web = "Веб"
    case documents = "Документи"
    case system = "Система"
    case away = "Перерва"
    case other = "Інше"

    var id: String { rawValue }

    static var assignableCases: [ActivityCategory] {
        allCases.filter { $0 != .away }
    }

    var symbol: String {
        switch self {
        case .development: return "hammer"
        case .communication: return "bubble.left.and.bubble.right"
        case .ai: return "sparkles"
        case .video: return "play.rectangle"
        case .web: return "globe"
        case .documents: return "doc.text"
        case .system: return "gearshape"
        case .away: return "cup.and.saucer"
        case .other: return "square.grid.2x2"
        }
    }
}

struct AppCategoryRule: Codable, Identifiable, Hashable {
    var appName: String
    var bundleIdentifier: String?
    var category: ActivityCategory

    var id: String {
        Self.key(appName: appName, bundleIdentifier: bundleIdentifier)
    }

    static func key(appName: String, bundleIdentifier: String?) -> String {
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return "bundle:\(bundleIdentifier.lowercased())"
        }
        return "name:\(appName.lowercased())"
    }

    func matches(appName: String, bundleIdentifier: String?) -> Bool {
        id == Self.key(appName: appName, bundleIdentifier: bundleIdentifier)
    }
}

struct CategoryTotal: Identifiable {
    let category: ActivityCategory
    let duration: TimeInterval
    var id: ActivityCategory { category }
}

enum ActivityClassifier {
    static func classify(
        appName: String,
        bundleIdentifier: String? = nil,
        title: String,
        isDevelopmentContext: Bool = false,
        isIdle: Bool
    ) -> ActivityCategory {
        if isIdle { return .away }

        let app = appName.lowercased()
        let identity = "\(appName) \(bundleIdentifier ?? "")".lowercased()
        let context = "\(appName) \(title)".lowercased()

        if isDevelopmentContext || app == "codex" || identity.contains("com.openai.codex") {
            return .development
        }
        if containsAny(context, ["claude", "chatgpt", "gemini", "perplexity", "ollama"]) {
            return .ai
        }
        if containsAny(context, ["youtube", "vimeo", "netflix", "megogo", "twitch"]) {
            return .video
        }
        if containsAny(app, ["xcode", "visual studio code", "cursor", "zed", "sublime", "intellij", "webstorm", "pycharm", "terminal", "iterm", "warp", "github desktop", "docker"]) {
            return .development
        }
        if containsAny(app, ["telegram", "slack", "messages", "discord", "whatsapp", "signal", "mail", "outlook", "zoom", "microsoft teams"]) {
            return .communication
        }
        if containsAny(app, ["safari", "chrome", "firefox", "arc", "brave", "edge", "orion"]) || app == "dia" {
            return .web
        }
        if containsAny(app, ["pages", "numbers", "keynote", "word", "excel", "powerpoint", "notes", "obsidian", "notion", "preview", "pdf"]) {
            return .documents
        }
        if containsAny(app, ["finder", "system settings", "activity monitor", "console", "daytrace"]) {
            return .system
        }
        return .other
    }

    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }
}

enum ContextTitleCleaner {
    static func prefersFocusedWebTitle(appName: String, bundleIdentifier: String?) -> Bool {
        let identity = "\(appName) \(bundleIdentifier ?? "")".lowercased()
        return [
            "claude", "anthropic", "chatgpt", "openai", "codex",
            "safari", "chrome", "chromium", "firefox", "brave",
            "edge", "arc", "orion", "dia"
        ].contains { identity.contains($0) }
    }

    static func clean(appName: String, bundleIdentifier: String?, title: String) -> String {
        var result = title
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let identity = "\(appName) \(bundleIdentifier ?? "")".lowercased()

        if identity.contains("telegram") {
            for prefix in ["Telegram @ ", "Telegram — ", "Telegram – ", "Telegram - "] where result.hasPrefix(prefix) {
                result.removeFirst(prefix.count)
                break
            }
        }

        if identity.contains("claude") || identity.contains("anthropic") {
            result = removingSuffixes([" - Claude Code", " — Claude Code", " – Claude Code", " - Claude", " — Claude", " – Claude"], from: result)
        }

        if identity.contains("chatgpt") || identity.contains("openai") || identity.contains("codex") {
            result = removingSuffixes([" - ChatGPT", " — ChatGPT", " – ChatGPT", " - Codex", " — Codex", " – Codex"], from: result)
        }

        let genericTitles = [appName.lowercased(), "telegram", "claude", "chatgpt", "codex"]
        return genericTitles.contains(result.lowercased()) ? "" : result
    }

    static func isDevelopmentContext(
        appName: String,
        bundleIdentifier: String?,
        rawTitle: String
    ) -> Bool {
        let identity = "\(appName) \(bundleIdentifier ?? "")".lowercased()
        if identity.contains("com.openai.codex") || appName.lowercased() == "codex" {
            return true
        }
        return (identity.contains("claude") || identity.contains("anthropic"))
            && rawTitle.lowercased().contains("claude code")
    }

    private static func removingSuffixes(_ suffixes: [String], from value: String) -> String {
        for suffix in suffixes where value.hasSuffix(suffix) {
            return String(value.dropLast(suffix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return value
    }
}

enum DurationText {
    static func compact(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded()))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours) год \(minutes) хв" }
        if minutes > 0 { return "\(minutes) хв" }
        return "< 1 хв"
    }
}

enum DaySelectionPolicy {
    static func shouldFollowRollover(
        selectedDate: Date,
        observedDate: Date,
        calendar: Calendar
    ) -> Bool {
        calendar.isDate(selectedDate, inSameDayAs: observedDate)
    }
}
