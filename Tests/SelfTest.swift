import Foundation

@main
enum SelfTest {
    static func main() {
        check(
            ActivityClassifier.classify(appName: "Safari", title: "Building a Mac App - YouTube", isIdle: false) == .video,
            "YouTube classification"
        )
        check(
            ActivityClassifier.classify(appName: "Claude", title: "Azure MCP setup", isIdle: false) == .ai,
            "Claude chat classification"
        )
        check(
            ActivityClassifier.classify(appName: "ChatGPT", title: "Vacation ideas", isIdle: false) == .ai,
            "ChatGPT chat classification"
        )
        check(
            ActivityClassifier.classify(
                appName: "ChatGPT",
                bundleIdentifier: "com.openai.codex",
                title: "Implement timeline",
                isIdle: false
            ) == .development,
            "Codex app classification"
        )
        check(
            ActivityClassifier.classify(
                appName: "Claude",
                bundleIdentifier: "com.anthropic.claudefordesktop",
                title: "Fix deploy",
                isDevelopmentContext: true,
                isIdle: false
            ) == .development,
            "Claude Code classification"
        )
        check(
            ActivityClassifier.classify(appName: "Visual Studio Code", title: "my-pet-project", isIdle: false) == .development,
            "development classification"
        )
        check(
            ActivityClassifier.classify(appName: "Obsidian", title: "Daily note", isIdle: false) == .documents,
            "Obsidian is not confused with Dia browser"
        )
        check(
            ActivityClassifier.classify(appName: "Telegram", title: "Family", isIdle: true) == .away,
            "idle classification"
        )
        check(
            ContextTitleCleaner.clean(
                appName: "Claude",
                bundleIdentifier: "com.anthropic.claudefordesktop",
                title: "Azure MCP setup - Claude Code"
            ) == "Azure MCP setup",
            "Claude task title cleanup"
        )
        check(
            ContextTitleCleaner.isDevelopmentContext(
                appName: "Claude",
                bundleIdentifier: "com.anthropic.claudefordesktop",
                rawTitle: "Azure MCP setup - Claude Code"
            ),
            "Claude Code context detection"
        )
        check(
            ContextTitleCleaner.clean(
                appName: "Telegram",
                bundleIdentifier: "ru.keepcoder.Telegram",
                title: "Telegram @ Oleksandr"
            ) == "Oleksandr",
            "Telegram chat title cleanup"
        )
        check(
            ContextTitleCleaner.prefersFocusedWebTitle(
                appName: "Google Chrome",
                bundleIdentifier: "com.google.Chrome"
            ),
            "browser web title preference"
        )
        check(
            AppCategoryRule.key(
                appName: "ChatGPT",
                bundleIdentifier: "com.openai.codex"
            ) == "bundle:com.openai.codex",
            "category rules prefer the stable bundle identifier"
        )
        check(
            AppCategoryRule.key(appName: "Custom App", bundleIdentifier: nil)
                == "name:custom app",
            "category rules fall back to a normalized app name"
        )
        check(
            ApplicationIdentity.isBrowser(
                appName: "Google Chrome",
                bundleIdentifier: "com.google.Chrome"
            ),
            "Chrome is recognized as a browser"
        )
        check(
            !ApplicationIdentity.isBrowser(appName: "Obsidian", bundleIdentifier: "md.obsidian"),
            "Obsidian is not confused with a browser"
        )
        let youtubeRule = AppCategoryRule(
            appName: "Google Chrome",
            bundleIdentifier: "com.google.Chrome",
            contextTitle: "A useful video - YouTube",
            category: .video
        )
        check(
            youtubeRule.matches(
                appName: "Google Chrome",
                bundleIdentifier: "com.google.Chrome",
                contextTitle: "(4) A useful video - YouTube"
            ),
            "browser tab rules ignore a leading notification count"
        )
        check(
            AppCategoryRule.normalizedContextTitle(
                "GitHub - Google Chrome – Олександр (Home)"
            ) == AppCategoryRule.normalizedContextTitle("GitHub"),
            "browser tab rules ignore browser and profile suffixes"
        )
        check(
            !youtubeRule.matches(
                appName: "Google Chrome",
                bundleIdentifier: "com.google.Chrome",
                contextTitle: "GitHub"
            ),
            "browser tab rules do not affect another tab"
        )
        let legacyRuleJSON = """
        {"appName":"Google Chrome","bundleIdentifier":"com.google.Chrome","category":"Веб"}
        """.data(using: .utf8)!
        let legacyRule = try? JSONDecoder().decode(AppCategoryRule.self, from: legacyRuleJSON)
        check(
            legacyRule?.contextTitle == nil && legacyRule?.category == .web,
            "existing application category rules remain decodable"
        )
        check(
            CategoryColorValue(red: 1.2, green: -0.1, blue: 0.5, opacity: 2)
                == CategoryColorValue(red: 1, green: 0, blue: 0.5, opacity: 1),
            "category color components stay in the displayable range"
        )

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let trackedDay = Date(timeIntervalSince1970: 1_780_704_000)
        check(
            DaySelectionPolicy.shouldFollowRollover(
                selectedDate: trackedDay.addingTimeInterval(60 * 60),
                observedDate: trackedDay,
                calendar: calendar
            ),
            "UI follows midnight rollover while showing the live day"
        )
        check(
            !DaySelectionPolicy.shouldFollowRollover(
                selectedDate: trackedDay.addingTimeInterval(-24 * 60 * 60),
                observedDate: trackedDay,
                calendar: calendar
            ),
            "UI preserves an explicitly selected historical day"
        )
        print("All DayTrace self-tests passed")
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ name: String) {
        guard condition() else {
            fputs("Self-test failed: \(name)\n", stderr)
            exit(1)
        }
    }
}
