import AppKit

enum MenuBarIcon {
    static let active = load(named: "MenuBarIconTemplate", fallbackSymbol: "clock")
    static let paused = load(named: "MenuBarIconPausedTemplate", fallbackSymbol: "pause.circle")

    private static func load(named name: String, fallbackSymbol: String) -> NSImage {
        if let url = Bundle.main.url(forResource: name, withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.isTemplate = true
            image.size = NSSize(width: 18, height: 18)
            return image
        }

        return NSImage(
            systemSymbolName: fallbackSymbol,
            accessibilityDescription: "DayTrace"
        ) ?? NSImage()
    }
}
