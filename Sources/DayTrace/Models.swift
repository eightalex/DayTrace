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

struct ActivityCategory: RawRepresentable, Codable, CaseIterable, Hashable, Identifiable {
    let rawValue: String

    init?(rawValue: String) {
        let normalized = Self.normalizedName(rawValue)
        guard !normalized.isEmpty else { return nil }
        self.rawValue = normalized
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        guard let category = Self(rawValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Category name cannot be empty"
            )
        }
        self = category
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    static let development = Self(rawValue: "Розробка")!
    static let communication = Self(rawValue: "Спілкування")!
    static let ai = Self(rawValue: "AI-інструменти")!
    static let video = Self(rawValue: "Відео")!
    static let web = Self(rawValue: "Веб")!
    static let documents = Self(rawValue: "Документи")!
    static let system = Self(rawValue: "Система")!
    static let away = Self(rawValue: "Перерва")!
    static let other = Self(rawValue: "Інше")!

    static let allCases: [ActivityCategory] = [
        .development,
        .communication,
        .ai,
        .video,
        .web,
        .documents,
        .system,
        .away,
        .other,
    ]

    var id: String { rawValue }

    static var assignableCases: [ActivityCategory] {
        allCases.filter { $0 != .away }
    }

    static func normalizedName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isBuiltIn: Bool {
        Self.allCases.contains(self)
    }

    var symbol: String {
        if self == .development { return "hammer" }
        if self == .communication { return "bubble.left.and.bubble.right" }
        if self == .ai { return "sparkles" }
        if self == .video { return "play.rectangle" }
        if self == .web { return "globe" }
        if self == .documents { return "doc.text" }
        if self == .system { return "gearshape" }
        if self == .away { return "cup.and.saucer" }
        if self == .other { return "square.grid.2x2" }
        return "tag"
    }
}

struct CategoryColorValue: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
        self.opacity = min(max(opacity, 0), 1)
    }
}

enum ApplicationIdentity {
    static func isBrowser(appName: String, bundleIdentifier: String?) -> Bool {
        let app = appName.lowercased()
        let bundle = (bundleIdentifier ?? "").lowercased()
        let browserNames = [
            "safari", "google chrome", "chromium", "firefox", "arc",
            "brave browser", "microsoft edge", "orion", "dia", "opera", "vivaldi"
        ]
        let browserBundleFragments = [
            "com.apple.safari", "com.google.chrome", "org.chromium", "org.mozilla.firefox",
            "company.thebrowser", "com.brave.browser", "com.microsoft.edgemac",
            "com.kagi.kagimacos", "com.operasoftware.opera", "com.vivaldi.vivaldi"
        ]
        return browserNames.contains(app)
            || browserBundleFragments.contains { bundle.contains($0) }
    }

    static func browserTabTitle(
        appName: String,
        bundleIdentifier: String?,
        windowTitle: String
    ) -> String? {
        guard isBrowser(appName: appName, bundleIdentifier: bundleIdentifier) else { return nil }
        let title = windowTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }
}

struct AppCategoryRule: Codable, Identifiable, Hashable {
    var appName: String
    var bundleIdentifier: String?
    var contextTitle: String?
    var category: ActivityCategory

    init(
        appName: String,
        bundleIdentifier: String?,
        contextTitle: String? = nil,
        category: ActivityCategory
    ) {
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.contextTitle = contextTitle
        self.category = category
    }

    var id: String {
        let applicationKey = Self.key(appName: appName, bundleIdentifier: bundleIdentifier)
        guard let contextTitle else { return applicationKey }
        return "\(applicationKey)|context:\(Self.normalizedContextTitle(contextTitle))"
    }

    var displayName: String {
        contextTitle.map(Self.canonicalContextTitle) ?? appName
    }

    var isContextSpecific: Bool {
        contextTitle != nil
    }

    static func key(appName: String, bundleIdentifier: String?) -> String {
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return "bundle:\(bundleIdentifier.lowercased())"
        }
        return "name:\(appName.lowercased())"
    }

    static func normalizedContextTitle(_ title: String) -> String {
        canonicalContextTitle(title).lowercased()
    }

    static func canonicalContextTitle(_ title: String) -> String {
        title
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "^\\(\\d+\\)\\s*", with: "", options: .regularExpression)
            .replacingOccurrences(
                of: "\\s+[-–—]\\s+(google chrome|safari|firefox|arc|brave browser|microsoft edge|orion|dia|opera|vivaldi)(?:\\s+[-–—]\\s+.*)?$",
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func matches(appName: String, bundleIdentifier: String?, contextTitle: String = "") -> Bool {
        guard Self.key(appName: self.appName, bundleIdentifier: self.bundleIdentifier)
            == Self.key(appName: appName, bundleIdentifier: bundleIdentifier) else { return false }
        guard let ownContextTitle = self.contextTitle else {
            return !ApplicationIdentity.isBrowser(
                appName: self.appName,
                bundleIdentifier: self.bundleIdentifier
            ) || Self.normalizedContextTitle(contextTitle).isEmpty
        }
        return Self.normalizedContextTitle(ownContextTitle)
            == Self.normalizedContextTitle(contextTitle)
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
        if isVideoService(
            appName: appName,
            bundleIdentifier: bundleIdentifier,
            title: title
        ) {
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

    static func isVideoService(
        appName: String,
        bundleIdentifier: String? = nil,
        title: String
    ) -> Bool {
        let app = appName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let bundle = (bundleIdentifier ?? "").lowercased()
        let normalizedTitle = title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let context = "\(app) \(normalizedTitle)"

        let videoAppNames = [
            "plex", "netflix", "max", "tv", "prime video", "disney+",
            "megogo", "sweet.tv", "twitch", "vimeo", "hulu", "crunchyroll"
        ]
        let videoBundleFragments = [
            "tv.plex.desktop", "com.netflix", "com.wbd", "com.hbo",
            "com.apple.tv", "com.amazon.avod", "com.disney", "com.megogo",
            "sweet.tv", "tv.twitch", "com.hulu", "com.crunchyroll"
        ]
        let videoTitleMarkers = [
            "youtube", "netflix", "hbo max", "prime video",
            "amazon prime video", "disney+", "disney plus", "apple tv+",
            "apple tv plus", "megogo", "sweet.tv", "sweet tv", "київстар тб",
            "kyivstar tv", "twitch", "vimeo", "hulu", "paramount+",
            "paramount plus", "peacock", "crunchyroll"
        ]
        let isMaxTitle = normalizedTitle == "max"
            || normalizedTitle.hasPrefix("max |")
            || normalizedTitle.hasPrefix("max:")
        let hasNamedService = normalizedTitle.range(
            of: "\\b(hbo|plex)\\b",
            options: [.regularExpression, .caseInsensitive]
        ) != nil

        return videoAppNames.contains(app)
            || videoBundleFragments.contains { bundle.contains($0) }
            || videoTitleMarkers.contains { context.contains($0) }
            || isMaxTitle
            || hasNamedService
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
