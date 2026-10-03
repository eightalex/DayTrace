import AppKit
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        summary
                        categoryGrid
                        timeline
                    }
                    .padding(24)
                }
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
                Text("Без Accessibility DayTrace бачить програму, але заголовок активного вікна може бути порожнім.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Надати доступ") { store.requestAccessibility() }
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
                        .foregroundStyle(.tint)
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

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Хронологія")
                    .font(.title3.bold())
                Spacer()
                Button("Показати дані у Finder") { store.revealDataFolder() }
                    .buttonStyle(.link)
            }

            LazyVStack(spacing: 0) {
                ForEach(store.sessionsForSelectedDay) { session in
                    SessionRow(session: session)
                    if session.id != store.sessionsForSelectedDay.last?.id {
                        Divider().padding(.leading, 104)
                    }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        }
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
                .foregroundStyle(session.isIdle ? Color.secondary : Color.accentColor)

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
            Divider()
            Button("Завершити") { NSApp.terminate(nil) }
        }
        .padding(6)
    }
}
