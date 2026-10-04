import AppKit
import Charts
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: ActivityStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if !store.accessibilityGranted {
                permissionBanner
                    .padding(.horizontal, 24)
                    .padding(.top, 18)
            }

            if store.sessionsForSelectedDay.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 18) {
                    summary
                    categoryGrid
                    DayTimelineChart(
                        sessions: store.sessionsForSelectedDay,
                        date: store.selectedDate
                    )
                    timelineHeader
                    timelineList
                }
                .padding(24)
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { store.refreshPermission() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DayTrace")
                    .font(.title2.bold())
                Text(dateTitle)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.select(date: Calendar.current.date(byAdding: .day, value: -1, to: store.selectedDate)!)
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.borderless)

            Button("Сьогодні") { store.selectToday() }
                .disabled(Calendar.current.isDateInToday(store.selectedDate))

            Button {
                let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: store.selectedDate)!
                store.select(date: tomorrow)
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.borderless)
            .disabled(Calendar.current.isDateInToday(store.selectedDate))

            Divider().frame(height: 22)

            Button {
                store.toggleDockVisibility()
            } label: {
                Image(systemName: store.isVisibleInDock ? "dock.rectangle" : "dock.arrow.up.rectangle")
            }
            .help(store.isVisibleInDock ? "Приховати з Dock" : "Показати в Dock")

            Button(store.isTracking ? "Призупинити" : "Продовжити") {
                store.toggleTracking()
            }
            .buttonStyle(.borderedProminent)
            .tint(store.isTracking ? .accentColor : .orange)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }

    private var permissionBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 3) {
                Text("Дозвольте доступ до назв вікон")
                    .font(.headline)
                Text("Якщо DayTrace уже увімкнений у списку, вимкніть і знову ввімкніть перемикач для /Applications/DayTrace.app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Відкрити налаштування") { store.requestAccessibility() }
        }
        .padding(14)
        .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("За цей день активності ще немає")
                .font(.title3.bold())
            Text("Залиште DayTrace запущеним — хронологія з’явиться автоматично.")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Активний час")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(DurationText.compact(store.activeDuration))
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Сесій")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(store.sessionsForSelectedDay.count)")
                    .font(.title2.bold())
            }
        }
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            ForEach(store.categoryTotals) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.category.symbol)
                        .frame(width: 24)
                        .foregroundStyle(item.category.timelineColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.category.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(DurationText.compact(item.duration))
                            .font(.headline)
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var timelineHeader: some View {
        HStack {
            Text("Хронологія")
                .font(.title3.bold())
            Spacer()
            Button("Показати дані у Finder") { store.revealDataFolder() }
                .buttonStyle(.link)
        }
    }

    private var timelineList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(store.sessionsForSelectedDay) { session in
                    SessionRow(session: session)
                    if session.id != store.sessionsForSelectedDay.last?.id {
                        Divider().padding(.leading, 104)
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var dateTitle: String {
        if Calendar.current.isDateInToday(store.selectedDate) { return "Сьогодні" }
        return store.selectedDate.formatted(.dateTime.day().month(.wide).year())
    }
}

private struct SessionRow: View {
    let session: ActivitySession

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .trailing, spacing: 3) {
                Text(session.startedAt, style: .time)
                    .font(.system(.subheadline, design: .monospaced))
                Text(DurationText.compact(session.duration))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 76, alignment: .trailing)

            Image(systemName: session.category.symbol)
                .frame(width: 24, height: 24)
                .foregroundStyle(session.isIdle ? Color.secondary : session.category.timelineColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(session.appName)
                    Text("•")
                    Text(session.category.rawValue)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

private struct DayTimelineChart: View {
    let sessions: [ActivitySession]
    let date: Date

    private let calendar = Calendar.autoupdatingCurrent
    private let axisValues: [Double] = [0, 21_600, 43_200, 64_800, 86_400]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Огляд дня")
                    .font(.subheadline.bold())
                Spacer()
                Text("00:00–24:00")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(sessions.filter { $0.duration > 0.5 }) { session in
                    BarMark(
                        xStart: .value("Початок", secondsSinceStart(of: session.startedAt)),
                        xEnd: .value("Кінець", secondsSinceStart(of: session.endedAt)),
                        y: .value("День", "Активність")
                    )
                    .foregroundStyle(session.category.timelineColor)
                    .opacity(session.isIdle ? 0.35 : 0.9)
                    .cornerRadius(3)
                    .accessibilityLabel(session.displayTitle)
                    .accessibilityValue(
                        "\(session.category.rawValue), \(DurationText.compact(session.duration))"
                    )
                }

                if calendar.isDateInToday(date) {
                    RuleMark(x: .value("Зараз", secondsSinceStart(of: Date())))
                        .foregroundStyle(.primary.opacity(0.65))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                }
            }
            .chartXScale(domain: 0...86_400)
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartXAxis {
                AxisMarks(values: axisValues) { value in
                    AxisGridLine()
                        .foregroundStyle(.secondary.opacity(0.18))
                    AxisTick()
                    AxisValueLabel {
                        if let seconds = value.as(Double.self) {
                            Text(String(format: "%02d:00", Int(seconds) / 3_600))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartPlotStyle { plotArea in
                plotArea
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .frame(height: 66)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private func secondsSinceStart(of value: Date) -> Double {
        let start = calendar.startOfDay(for: date)
        return min(86_400, max(0, value.timeIntervalSince(start)))
    }
}

private extension ActivityCategory {
    var timelineColor: Color {
        switch self {
        case .development: return .indigo
        case .communication: return .teal
        case .ai: return .purple
        case .video: return .red
        case .web: return .blue
        case .documents: return .orange
        case .system: return .gray
        case .away: return .secondary
        case .other: return .brown
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var store: ActivityStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Сьогодні: \(DurationText.compact(store.todayActiveDuration))")
                .font(.headline)
            Button("Відкрити DayTrace") {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button(store.isTracking ? "Призупинити запис" : "Продовжити запис") {
                store.toggleTracking()
            }
            Button(store.isVisibleInDock ? "Приховати з Dock" : "Показати в Dock") {
                store.toggleDockVisibility()
            }
            Divider()
            Button("Завершити") { NSApp.terminate(nil) }
        }
        .padding(6)
    }
}
