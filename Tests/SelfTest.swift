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
            "Claude classification"
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
        print("All DayTrace self-tests passed")
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ name: String) {
        guard condition() else {
            fputs("Self-test failed: \(name)\n", stderr)
            exit(1)
        }
    }
}
