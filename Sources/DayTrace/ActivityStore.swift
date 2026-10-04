import AppKit
import Combine
import Foundation

@MainActor
final class ActivityStore: ObservableObject {
    @Published private(set) var sessions: [ActivitySession] = []
    @Published private(set) var isTracking = true
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var isVisibleInDock = true
    @Published private(set) var categoryRules: [AppCategoryRule] = []
    @Published private(set) var categoryColors: [ActivityCategory: CategoryColorValue] = [:]
    @Published private(set) var recentBrowserTabs: [AppCategoryRule] = []
    @Published var selectedDate = Date()

    private let calendar = Calendar.autoupdatingCurrent
    private let sampleInterval: TimeInterval = 3
    private let persistenceInterval: TimeInterval = 30
    private var timer: Timer?
    private var lastSampleAt: Date?
    private var lastPersistedAt: Date?
    private var observedDay = Date()
    private var trackingSessions: [ActivitySession] = []

    init() {
        isVisibleInDock = UserDefaults.standard.object(forKey: "showInDock") as? Bool ?? true
        accessibilityGranted = ActivityCapture.accessibilityGranted(prompt: false)
        categoryRules = loadCategoryRules()
        categoryColors = loadCategoryColors()
        observedDay = selectedDate
        trackingSessions = loadSessions(for: observedDay)
        sessions = trackingSessions
        refreshRecentBrowserTabs()
        startTimer()
        DispatchQueue.main.async { [weak self] in
            self?.applyDockVisibility(activate: false)
        }
    }

    deinit {
        timer?.invalidate()
    }

    var sessionsForSelectedDay: [ActivitySession] {
        sessions.sorted { $0.startedAt > $1.startedAt }
    }

    var activeDuration: TimeInterval {
        sessions.filter { !$0.isIdle }.reduce(0) { $0 + $1.duration }
    }

    var todayActiveDuration: TimeInterval {
        trackingSessions.filter { !$0.isIdle }.reduce(0) { $0 + $1.duration }
    }

    var categoryTotals: [CategoryTotal] {
        Dictionary(grouping: sessions.filter { !$0.isIdle }, by: \.category)
            .map { CategoryTotal(category: $0.key, duration: $0.value.reduce(0) { $0 + $1.duration }) }
            .sorted { $0.duration > $1.duration }
    }

    var categorizedApplications: [AppCategoryRule] {
        var applications: [String: AppCategoryRule] = [:]
        for session in sessions.sorted(by: { $0.startedAt < $1.startedAt }) where !session.isIdle {
            if ApplicationIdentity.isBrowser(
                appName: session.appName,
                bundleIdentifier: session.bundleIdentifier
            ) {
                continue
            }
            let application = AppCategoryRule(
                appName: session.appName,
                bundleIdentifier: session.bundleIdentifier,
                category: session.category
            )
            applications[application.id] = application
        }
        for rule in categoryRules where rule.isContextSpecific
            || !ApplicationIdentity.isBrowser(
                appName: rule.appName,
                bundleIdentifier: rule.bundleIdentifier
            ) {
            applications[rule.id] = rule
        }
        return applications.values.sorted {
            let nameOrder = $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
            if nameOrder != .orderedSame { return nameOrder == .orderedAscending }
            return $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
        }
    }

    func categorizedApplications(for category: ActivityCategory) -> [AppCategoryRule] {
        categorizedApplications
            .filter { $0.category == category }
    }

    func assignCategory(_ category: ActivityCategory, to session: ActivitySession) {
        guard !session.isIdle, category != .away else { return }
        setCategoryRule(
            AppCategoryRule(
                appName: session.appName,
                bundleIdentifier: session.bundleIdentifier,
                contextTitle: ApplicationIdentity.browserTabTitle(
                    appName: session.appName,
                    bundleIdentifier: session.bundleIdentifier,
                    windowTitle: session.windowTitle
                ),
                category: category
            )
        )
    }

    func moveCategoryRule(id: String, to category: ActivityCategory) {
        guard category != .away,
              let rule = (categorizedApplications + recentBrowserTabs)
                .first(where: { $0.id == id }) else { return }
        var movedRule = rule
        movedRule.category = category
        setCategoryRule(movedRule)
    }

    func setCategoryColor(_ color: CategoryColorValue, for category: ActivityCategory) {
        guard category != .away else { return }
        categoryColors[category] = color
        saveCategoryColors()
    }

    func toggleTracking() {
        isTracking.toggle()
        if isTracking {
            lastSampleAt = nil
            captureNow()
        } else {
            closeCurrentSession(at: Date())
            saveTrackingSessions(for: observedDay)
        }
    }

    func toggleDockVisibility() {
        isVisibleInDock.toggle()
        UserDefaults.standard.set(isVisibleInDock, forKey: "showInDock")
        applyDockVisibility(activate: isVisibleInDock)
    }

    func requestAccessibility() {
        accessibilityGranted = ActivityCapture.accessibilityGranted(prompt: true)
        if !accessibilityGranted,
           let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(settingsURL)
        }
    }

    func refreshPermission() {
        accessibilityGranted = ActivityCapture.accessibilityGranted(prompt: false)
    }

    func select(date: Date) {
        guard !calendar.isDate(date, inSameDayAs: selectedDate) else { return }
        selectedDate = date
        sessions = calendar.isDate(date, inSameDayAs: observedDay)
            ? trackingSessions
            : loadSessions(for: date)
    }

    func selectToday() {
        select(date: Date())
    }

    func revealDataFolder() {
        try? FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
        NSWorkspace.shared.activateFileViewerSelecting([dataDirectory])
    }

    private func applyDockVisibility(activate: Bool) {
        NSApp.setActivationPolicy(isVisibleInDock ? .regular : .accessory)
        if activate {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.captureNow() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        captureNow()
    }

    private func captureNow() {
        guard isTracking else { return }
        let now = Date()

        if !calendar.isDate(now, inSameDayAs: observedDay) {
            let shouldFollowNewDay = DaySelectionPolicy.shouldFollowRollover(
                selectedDate: selectedDate,
                observedDate: observedDay,
                calendar: calendar
            )
            closeCurrentSession(at: calendar.startOfDay(for: now))
            saveTrackingSessions(for: observedDay)
            observedDay = now
            trackingSessions = loadSessions(for: now)
            lastPersistedAt = nil
            if shouldFollowNewDay {
                selectedDate = now
                sessions = trackingSessions
            }
        }

        guard let snapshot = ActivityCapture.snapshot() else { return }
        accessibilityGranted = ActivityCapture.accessibilityGranted(prompt: false)

        let gap = lastSampleAt.map { now.timeIntervalSince($0) } ?? 0
        if gap > sampleInterval * 4 {
            closeCurrentSession(at: lastSampleAt.map { $0.addingTimeInterval(sampleInterval) } ?? now)
        }

        let automaticCategory = ActivityClassifier.classify(
            appName: snapshot.appName,
            bundleIdentifier: snapshot.bundleIdentifier,
            title: snapshot.windowTitle,
            isDevelopmentContext: snapshot.isDevelopmentContext,
            isIdle: snapshot.isIdle
        )
        let category = assignedCategory(
            appName: snapshot.appName,
            bundleIdentifier: snapshot.bundleIdentifier,
            windowTitle: snapshot.windowTitle,
            automaticCategory: automaticCategory,
            isIdle: snapshot.isIdle
        )

        var didStartSession = false
        if var current = trackingSessions.last,
           current.appName == snapshot.appName,
           current.windowTitle == snapshot.windowTitle,
           current.category == category,
           current.isIdle == snapshot.isIdle {
            current.endedAt = now
            current.category = category
            trackingSessions[trackingSessions.count - 1] = current
        } else {
            closeCurrentSession(at: now)
            trackingSessions.append(ActivitySession(
                id: UUID(),
                appName: snapshot.appName,
                bundleIdentifier: snapshot.bundleIdentifier,
                windowTitle: snapshot.windowTitle,
                category: category,
                startedAt: now,
                endedAt: now,
                isIdle: snapshot.isIdle
            ))
            didStartSession = true
        }

        lastSampleAt = now
        if calendar.isDate(selectedDate, inSameDayAs: now) {
            sessions = trackingSessions
        }
        if didStartSession || lastPersistedAt.map({ now.timeIntervalSince($0) >= persistenceInterval }) ?? true {
            saveTrackingSessions(for: now)
        }
        if didStartSession {
            refreshRecentBrowserTabs()
        }
    }

    private func closeCurrentSession(at date: Date) {
        guard !trackingSessions.isEmpty else { return }
        let index = trackingSessions.count - 1
        trackingSessions[index].endedAt = max(
            trackingSessions[index].startedAt,
            min(trackingSessions[index].endedAt.addingTimeInterval(sampleInterval), date)
        )
    }

    private func saveTrackingSessions(for date: Date) {
        saveSessions(trackingSessions, for: date)
        lastPersistedAt = Date()
    }

    private func setCategoryRule(_ rule: AppCategoryRule) {
        if let index = categoryRules.firstIndex(where: { $0.id == rule.id }) {
            categoryRules[index] = rule
        } else {
            categoryRules.append(rule)
        }
        categoryRules.sort {
            let appOrder = $0.appName.localizedCaseInsensitiveCompare($1.appName)
            if appOrder != .orderedSame { return appOrder == .orderedAscending }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        saveCategoryRules()

        apply(rule, to: &trackingSessions)
        if calendar.isDate(selectedDate, inSameDayAs: observedDay) {
            sessions = trackingSessions
        } else {
            apply(rule, to: &sessions)
        }
        saveTrackingSessions(for: observedDay)
        refreshRecentBrowserTabs()
    }

    private func apply(_ rule: AppCategoryRule, to target: inout [ActivitySession]) {
        for index in target.indices where !target[index].isIdle
            && rule.matches(
                appName: target[index].appName,
                bundleIdentifier: target[index].bundleIdentifier,
                contextTitle: target[index].windowTitle
            ) {
            target[index].category = rule.category
        }
    }

    private func assignedCategory(
        appName: String,
        bundleIdentifier: String?,
        windowTitle: String,
        automaticCategory: ActivityCategory,
        isIdle: Bool
    ) -> ActivityCategory {
        guard !isIdle else { return .away }
        let matchingRules = categoryRules.filter {
            $0.matches(
                appName: appName,
                bundleIdentifier: bundleIdentifier,
                contextTitle: windowTitle
            )
        }
        return matchingRules.first(where: { $0.isContextSpecific })?.category
            ?? matchingRules.first(where: { !$0.isContextSpecific })?.category
            ?? automaticCategory
    }

    private var dataDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("DayTrace", isDirectory: true)
    }

    private func fileURL(for date: Date) -> URL {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return dataDirectory.appendingPathComponent("activity-\(formatter.string(from: date)).json")
    }

    private var categoryRulesURL: URL {
        dataDirectory.appendingPathComponent("category-rules.json")
    }

    private var categoryColorsURL: URL {
        dataDirectory.appendingPathComponent("category-colors.json")
    }

    private func loadSessions(for date: Date) -> [ActivitySession] {
        let url = fileURL(for: date)
        guard let data = try? Data(contentsOf: url),
              var result = try? JSONDecoder.dayTrace.decode([ActivitySession].self, from: data) else { return [] }
        for index in result.indices where !result[index].isIdle
            && ApplicationIdentity.isBrowser(
                appName: result[index].appName,
                bundleIdentifier: result[index].bundleIdentifier
            ) {
            let automaticCategory = ActivityClassifier.classify(
                appName: result[index].appName,
                bundleIdentifier: result[index].bundleIdentifier,
                title: result[index].windowTitle,
                isIdle: false
            )
            result[index].category = assignedCategory(
                appName: result[index].appName,
                bundleIdentifier: result[index].bundleIdentifier,
                windowTitle: result[index].windowTitle,
                automaticCategory: automaticCategory,
                isIdle: false
            )
        }
        for rule in categoryRules.sorted(by: { !$0.isContextSpecific && $1.isContextSpecific }) {
            apply(rule, to: &result)
        }
        return result
    }

    private func saveSessions(_ value: [ActivitySession], for date: Date) {
        do {
            try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder.dayTrace.encode(value)
            try data.write(to: fileURL(for: date), options: .atomic)
        } catch {
            NSLog("DayTrace could not save activity: %@", error.localizedDescription)
        }
    }

    private func loadCategoryRules() -> [AppCategoryRule] {
        guard let data = try? Data(contentsOf: categoryRulesURL),
              let rules = try? JSONDecoder.dayTrace.decode([AppCategoryRule].self, from: data) else {
            return []
        }
        return rules
    }

    private func saveCategoryRules() {
        do {
            try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder.dayTrace.encode(categoryRules)
            try data.write(to: categoryRulesURL, options: .atomic)
        } catch {
            NSLog("DayTrace could not save category rules: %@", error.localizedDescription)
        }
    }

    private func refreshRecentBrowserTabs(referenceDate: Date = Date()) {
        let today = calendar.startOfDay(for: referenceDate)
        let cutoff = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        let pinnedTabIDs = Set(categoryRules.filter(\.isContextSpecific).map(\.id))
        var latestTabs: [String: (rule: AppCategoryRule, lastSeenAt: Date)] = [:]

        for dayOffset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                continue
            }
            let daySessions = calendar.isDate(day, inSameDayAs: observedDay)
                ? trackingSessions
                : loadSessions(for: day)

            for session in daySessions where !session.isIdle && session.endedAt >= cutoff {
                guard let title = ApplicationIdentity.browserTabTitle(
                    appName: session.appName,
                    bundleIdentifier: session.bundleIdentifier,
                    windowTitle: session.windowTitle
                ) else { continue }

                let rule = AppCategoryRule(
                    appName: session.appName,
                    bundleIdentifier: session.bundleIdentifier,
                    contextTitle: title,
                    category: session.category
                )
                guard !pinnedTabIDs.contains(rule.id) else { continue }
                if latestTabs[rule.id]?.lastSeenAt ?? .distantPast < session.endedAt {
                    latestTabs[rule.id] = (rule, session.endedAt)
                }
            }
        }

        recentBrowserTabs = latestTabs.values
            .sorted { $0.lastSeenAt > $1.lastSeenAt }
            .map(\.rule)
    }

    private func loadCategoryColors() -> [ActivityCategory: CategoryColorValue] {
        guard let data = try? Data(contentsOf: categoryColorsURL),
              let storedColors = try? JSONDecoder.dayTrace.decode(
                  [String: CategoryColorValue].self,
                  from: data
              ) else { return [:] }

        return Dictionary(uniqueKeysWithValues: storedColors.compactMap { name, color in
            guard let category = ActivityCategory(rawValue: name), category != .away else {
                return nil
            }
            return (category, color)
        })
    }

    private func saveCategoryColors() {
        do {
            try FileManager.default.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
            let storedColors = Dictionary(uniqueKeysWithValues: categoryColors.map {
                ($0.key.rawValue, $0.value)
            })
            let data = try JSONEncoder.dayTrace.encode(storedColors)
            try data.write(to: categoryColorsURL, options: .atomic)
        } catch {
            NSLog("DayTrace could not save category colors: %@", error.localizedDescription)
        }
    }
}

private extension JSONEncoder {
    static var dayTrace: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var dayTrace: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
