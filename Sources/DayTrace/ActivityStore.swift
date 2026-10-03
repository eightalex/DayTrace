import AppKit
import Combine
import Foundation

@MainActor
final class ActivityStore: ObservableObject {
    @Published private(set) var sessions: [ActivitySession] = []
    @Published private(set) var isTracking = true
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var isVisibleInDock = true
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
        observedDay = selectedDate
        trackingSessions = loadSessions(for: observedDay)
        sessions = trackingSessions
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
            closeCurrentSession(at: calendar.startOfDay(for: now))
            saveTrackingSessions(for: observedDay)
            observedDay = now
            trackingSessions = loadSessions(for: now)
            lastPersistedAt = nil
            if calendar.isDate(selectedDate, inSameDayAs: now) {
                sessions = trackingSessions
            }
        }

        guard let snapshot = ActivityCapture.snapshot() else { return }
        accessibilityGranted = ActivityCapture.accessibilityGranted(prompt: false)

        let gap = lastSampleAt.map { now.timeIntervalSince($0) } ?? 0
        if gap > sampleInterval * 4 {
            closeCurrentSession(at: lastSampleAt.map { $0.addingTimeInterval(sampleInterval) } ?? now)
        }

        let category = ActivityClassifier.classify(
            appName: snapshot.appName,
            title: snapshot.windowTitle,
            isIdle: snapshot.isIdle
        )

        var didStartSession = false
        if var current = trackingSessions.last,
           current.appName == snapshot.appName,
           current.windowTitle == snapshot.windowTitle,
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

    private func loadSessions(for date: Date) -> [ActivitySession] {
        let url = fileURL(for: date)
        guard let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder.dayTrace.decode([ActivitySession].self, from: data) else { return [] }
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
