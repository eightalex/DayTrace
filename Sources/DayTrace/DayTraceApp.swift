import SwiftUI

@main
struct DayTraceApp: App {
    @StateObject private var store = ActivityStore()

    var body: some Scene {
        WindowGroup("DayTrace", id: "main") {
            ContentView(store: store)
        }
        .defaultSize(width: 880, height: 680)

        MenuBarExtra("DayTrace", systemImage: store.isTracking ? "clock.fill" : "pause.circle") {
            MenuBarView(store: store)
        }
    }
}
