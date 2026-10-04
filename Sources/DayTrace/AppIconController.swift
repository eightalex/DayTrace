import AppKit

@MainActor
final class AppIconController {
    static let shared = AppIconController()

    private var appearanceObserver: NSObjectProtocol?

    private init() {}

    func start() {
        guard appearanceObserver == nil else { return }

        appearanceObserver = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateIcon()
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.updateIcon()
        }
    }

    private func updateIcon() {
        guard let application = NSApp else { return }
        let appearance = application.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        let iconName = appearance == .darkAqua ? "DayTraceDark" : "DayTrace"
        guard let iconURL = Bundle.main.url(forResource: iconName, withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL) else { return }
        application.applicationIconImage = icon
    }
}
