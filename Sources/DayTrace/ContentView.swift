import AppKit
import Charts
import SwiftUI

private enum ContentTab: String, CaseIterable, Identifiable {
    case timeline = "Хронологія"
    case categories = "Категорії"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .timeline: return "clock"
        case .categories: return "square.grid.2x2"
        }
    }
}

@MainActor
private final class ContentViewState: ObservableObject {
    @Published var selectedTab: ContentTab = .timeline
}

struct ContentView: View {
    @ObservedObject var store: ActivityStore
    @StateObject private var viewState = ContentViewState()

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if viewState.selectedTab == .timeline {
                timelineContent
            } else {
                CategoryManagerView(store: store)
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { store.refreshPermission() }
    }

    @ViewBuilder
    private var timelineContent: some View {
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
                    date: store.selectedDate,
                    categoryColors: store.categoryColors
                )
                timelineHeader
                timelineList
            }
            .padding(24)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DayTrace")
                    .font(.title2.bold())
                Text(viewState.selectedTab == .timeline ? dateTitle : "Менеджер категорій")
                    .foregroundStyle(.secondary)
            }

            Picker("Розділ", selection: $viewState.selectedTab) {
                ForEach(ContentTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.symbol)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 250)

            Spacer()

            if viewState.selectedTab == .timeline {
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
            }

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
                        .foregroundStyle(store.timelineColor(for: item.category))
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
                    SessionRow(
                        session: session,
                        color: store.timelineColor(for: session.category)
                    ) { category in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.assignCategory(category, to: session)
                        }
                    }
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
    let color: Color
    let onCategoryChange: (ActivityCategory) -> Void

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
                .foregroundStyle(session.isIdle ? Color.secondary : color)

            VStack(alignment: .leading, spacing: 3) {
                Text(session.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(session.appName)
                    Text("•")
                    if session.isIdle {
                        Text(session.category.rawValue)
                    } else {
                        Menu {
                            ForEach(ActivityCategory.assignableCases) { category in
                                Button {
                                    onCategoryChange(category)
                                } label: {
                                    Label(category.rawValue, systemImage: category.symbol)
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: session.category.symbol)
                                Text(session.category.rawValue)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .semibold))
                            }
                            .foregroundStyle(color)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                color.opacity(0.1),
                                in: Capsule()
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()
                        .help("Змінити категорію для \(session.appName)")
                    }
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

private struct CategoryManagerView: View {
    @ObservedObject var store: ActivityStore

    private let columns = [
        GridItem(.adaptive(minimum: 300, maximum: 520), spacing: 14, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Застосунки за категоріями")
                        .font(.title3.bold())
                    Text("Перетягування в інший блок змінює та закріплює категорію застосунку.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(store.categorizedApplications.count) застосунків")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(ActivityCategory.assignableCases) { category in
                        CategoryRuleCard(
                            category: category,
                            rules: store.categorizedApplications(for: category),
                            color: store.timelineColor(for: category),
                            onColorChange: { color in
                                store.setCategoryColor(CategoryColorValue(color: color), for: category)
                            }
                        ) { ruleID in
                            store.moveCategoryRule(id: ruleID, to: category)
                        }
                    }
                }
                // Keep scaled drop targets inside the scroll view's clipping bounds.
                .padding(6)
            }
        }
        .padding(24)
    }
}

private struct CategoryRuleCard: View {
    let category: ActivityCategory
    let rules: [AppCategoryRule]
    let color: Color
    let onColorChange: (Color) -> Void
    let onMove: (String) -> Void

    @StateObject private var dropState = CategoryDropState()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: category.symbol)
                    .foregroundStyle(color)
                    .frame(width: 24, height: 24)
                HStack(spacing: 6) {
                    Text(category.rawValue)
                        .font(.headline)
                        .lineLimit(1)
                    CompactCategoryColorPicker(
                        category: category,
                        color: color,
                        onChange: onColorChange
                    )
                    .frame(width: 14, height: 14)
                }
                .layoutPriority(1)
                Spacer()
                Text("\(rules.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .fixedSize()
            }

            if rules.isEmpty {
                Text("Перетягніть застосунок сюди")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
            } else {
                PillFlowLayout(spacing: 8) {
                    ForEach(rules) { rule in
                        AppRulePill(rule: rule, color: color)
                            .draggable(rule.id) {
                                AppRulePill(rule: rule, color: color)
                                    .opacity(0.9)
                            }
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .background(
            color.opacity(dropState.isTargeted ? 0.14 : 0.055),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    color.opacity(dropState.isTargeted ? 0.75 : 0.16),
                    lineWidth: dropState.isTargeted ? 2 : 1
                )
        }
        .scaleEffect(dropState.isTargeted ? 1.015 : 1)
        .dropDestination(for: String.self) { ruleIDs, _ in
            guard let ruleID = ruleIDs.first else { return false }
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                onMove(ruleID)
            }
            return true
        } isTargeted: { isTargeted in
            withAnimation(.easeInOut(duration: 0.16)) {
                dropState.isTargeted = isTargeted
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.8), value: rules)
    }
}

private struct CompactCategoryColorPicker: NSViewRepresentable {
    let category: ActivityCategory
    let color: Color
    let onChange: (Color) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeNSView(context: Context) -> NSColorWell {
        let colorWell = NSColorWell(frame: .zero)
        colorWell.colorWellStyle = .minimal
        colorWell.color = NSColor(color)
        colorWell.target = context.coordinator
        colorWell.action = #selector(Coordinator.colorChanged(_:))
        colorWell.toolTip = "Змінити колір категорії \(category.rawValue)"
        colorWell.setAccessibilityLabel("Колір категорії \(category.rawValue)")
        return colorWell
    }

    func updateNSView(_ colorWell: NSColorWell, context: Context) {
        context.coordinator.onChange = onChange
        let updatedColor = NSColor(color)
        if !colorWell.color.isEqual(updatedColor) {
            colorWell.color = updatedColor
        }
        colorWell.toolTip = "Змінити колір категорії \(category.rawValue)"
        colorWell.setAccessibilityLabel("Колір категорії \(category.rawValue)")
    }

    final class Coordinator: NSObject {
        var onChange: (Color) -> Void

        init(onChange: @escaping (Color) -> Void) {
            self.onChange = onChange
        }

        @objc func colorChanged(_ sender: NSColorWell) {
            onChange(Color(nsColor: sender.color))
        }
    }
}

@MainActor
private final class CategoryDropState: ObservableObject {
    @Published var isTargeted = false
}

private struct AppRulePill: View {
    let rule: AppCategoryRule
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            ApplicationIcon(bundleIdentifier: rule.bundleIdentifier)
            Text(rule.appName)
                .font(.caption.weight(.medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(color.opacity(0.13), in: Capsule())
        .overlay {
            Capsule()
                .stroke(color.opacity(0.18), lineWidth: 1)
        }
        .contentShape(Capsule())
    }
}

private struct ApplicationIcon: View {
    let bundleIdentifier: String?

    var body: some View {
        Group {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 16, height: 16)
    }

    private var icon: NSImage? {
        guard let bundleIdentifier,
              let appURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleIdentifier
              ) else { return nil }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
}

private struct PillFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            usedWidth = max(usedWidth, x + size.width)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: min(maxWidth, usedWidth), height: y + rowHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct DayTimelineChart: View {
    let sessions: [ActivitySession]
    let date: Date
    let categoryColors: [ActivityCategory: CategoryColorValue]

    @StateObject private var hoverState = TimelineHoverState()

    private let calendar = Calendar.autoupdatingCurrent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Огляд дня")
                    .font(.subheadline.bold())
                Spacer()
                Text(visibleRangeTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let visibleDomain {
                ZStack(alignment: .topLeading) {
                    Chart {
                        ForEach(visibleSessions) { session in
                            BarMark(
                                xStart: .value("Початок", visibleStart(for: session)),
                                xEnd: .value("Кінець", visibleEnd(for: session)),
                                y: .value("День", "Активність"),
                                height: .ratio(1)
                            )
                            .foregroundStyle(
                                session.isIdle
                                    ? Color.secondary
                                    : timelineColor(for: session.category)
                            )
                            .cornerRadius(0)
                            .opacity(markOpacity(for: session))
                            .accessibilityLabel(session.displayTitle)
                            .accessibilityValue(
                                "\(session.category.rawValue), \(DurationText.compact(session.duration))"
                            )
                        }

                        if calendar.isDateInToday(date),
                           visibleDomain.contains(secondsSinceStart(of: Date())) {
                            RuleMark(x: .value("Зараз", secondsSinceStart(of: Date())))
                                .foregroundStyle(.primary.opacity(0.65))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        }
                    }
                    .chartXScale(domain: visibleDomain)
                    .chartYAxis(.hidden)
                    .chartLegend(.hidden)
                    .chartXAxis {
                        AxisMarks(values: axisValues(for: visibleDomain)) { value in
                            AxisGridLine()
                                .foregroundStyle(.secondary.opacity(0.18))
                            AxisTick()
                            AxisValueLabel {
                                if let seconds = value.as(Double.self) {
                                    Text(timeLabel(for: seconds))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .chartPlotStyle { plotArea in
                        plotArea
                            .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            ZStack {
                                idlePattern(proxy: proxy, geometry: geometry)
                                    .allowsHitTesting(false)

                                Rectangle()
                                    .fill(.clear)
                                    .contentShape(Rectangle())
                                    .onContinuousHover { phase in
                                        updateHover(phase, proxy: proxy, geometry: geometry)
                                    }
                            }
                        }
                    }
                    .animation(.easeOut(duration: 0.12), value: hoverState.session?.id)
                    .frame(height: 76)

                    if let hoveredSession = hoverState.session {
                        TimelineTooltip(session: hoveredSession)
                            .offset(x: tooltipOffset, y: -58)
                            .zIndex(10)
                            .allowsHitTesting(false)
                            .transition(.opacity)
                    }
                }
                .zIndex(10)
            } else {
                Text("Активних сесій ще немає")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(
                        Color(nsColor: .textBackgroundColor).opacity(0.5),
                        in: RoundedRectangle(cornerRadius: 6)
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    }

    private var activeSessions: [ActivitySession] {
        sessions.filter { !$0.isIdle && $0.duration > 0.5 }
    }

    private var visibleDomain: ClosedRange<Double>? {
        guard let firstStart = activeSessions.map(\.startedAt).min(),
              let lastEnd = activeSessions.map(\.endedAt).max() else { return nil }

        let lowerBound = secondsSinceStart(of: firstStart)
        let upperBound = max(secondsSinceStart(of: lastEnd), lowerBound + 60)
        return lowerBound...min(86_400, upperBound)
    }

    private var visibleSessions: [ActivitySession] {
        guard let visibleDomain else { return [] }
        return sessions
            .filter {
                $0.duration > 0.5
                    && secondsSinceStart(of: $0.endedAt) > visibleDomain.lowerBound
                    && secondsSinceStart(of: $0.startedAt) < visibleDomain.upperBound
            }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private var visibleRangeTitle: String {
        guard let visibleDomain else { return "" }
        return "\(timeLabel(for: visibleDomain.lowerBound))–\(timeLabel(for: visibleDomain.upperBound))"
    }

    private var tooltipOffset: CGFloat {
        let tooltipWidth: CGFloat = 250
        return max(0, min(hoverState.x - tooltipWidth / 2, hoverState.width - tooltipWidth))
    }

    private func markOpacity(for session: ActivitySession) -> Double {
        guard let hoveredSession = hoverState.session else {
            return session.isIdle ? 0.28 : 0.9
        }
        if hoveredSession.id == session.id {
            return session.isIdle ? 0.5 : 1
        }
        return session.isIdle ? 0.16 : 0.38
    }

    private func idlePattern(proxy: ChartProxy, geometry: GeometryProxy) -> some View {
        Canvas { context, _ in
            let plotFrame = geometry[proxy.plotAreaFrame]

            for session in visibleSessions where session.isIdle {
                guard let startX = proxy.position(forX: visibleStart(for: session)),
                      let endX = proxy.position(forX: visibleEnd(for: session)) else { continue }

                let rect = CGRect(
                    x: plotFrame.minX + min(startX, endX),
                    y: plotFrame.minY,
                    width: abs(endX - startX),
                    height: plotFrame.height
                )
                guard rect.width > 0 else { continue }

                context.drawLayer { layer in
                    layer.clip(to: Path(rect))
                    var stripeX = rect.minX - rect.height
                    while stripeX < rect.maxX {
                        var stripe = Path()
                        stripe.move(to: CGPoint(x: stripeX, y: rect.maxY))
                        stripe.addLine(to: CGPoint(x: stripeX + rect.height, y: rect.minY))
                        layer.stroke(
                            stripe,
                            with: .color(.secondary.opacity(
                                hoverState.session?.id == session.id ? 0.75 : 0.48
                            )),
                            lineWidth: 1
                        )
                        stripeX += 7
                    }
                }
            }
        }
    }

    private func visibleStart(for session: ActivitySession) -> Double {
        max(visibleDomain?.lowerBound ?? 0, secondsSinceStart(of: session.startedAt))
    }

    private func visibleEnd(for session: ActivitySession) -> Double {
        min(visibleDomain?.upperBound ?? 86_400, secondsSinceStart(of: session.endedAt))
    }

    private func updateHover(
        _ phase: HoverPhase,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) {
        switch phase {
        case .active(let location):
            let plotFrame = geometry[proxy.plotAreaFrame]
            let plotX = location.x - plotFrame.minX
            guard plotX >= 0,
                  plotX <= plotFrame.width,
                  let seconds: Double = proxy.value(atX: plotX) else {
                hoverState.session = nil
                return
            }

            hoverState.width = geometry.size.width
            hoverState.x = location.x
            hoverState.session = visibleSessions.last {
                visibleStart(for: $0) <= seconds && seconds <= visibleEnd(for: $0)
            }
        case .ended:
            hoverState.session = nil
        }
    }

    private func axisValues(for domain: ClosedRange<Double>) -> [Double] {
        let span = domain.upperBound - domain.lowerBound
        let stride: Double
        switch span {
        case ...1_800: stride = 300
        case ...3_600: stride = 900
        case ...10_800: stride = 1_800
        case ...28_800: stride = 3_600
        case ...57_600: stride = 7_200
        default: stride = 14_400
        }

        var values: [Double] = []
        var value = ceil(domain.lowerBound / stride) * stride
        while value <= domain.upperBound {
            values.append(value)
            value += stride
        }
        if values.count < 2 {
            return [domain.lowerBound, domain.upperBound]
        }
        return values
    }

    private func timeLabel(for seconds: Double) -> String {
        let value = calendar.startOfDay(for: date).addingTimeInterval(seconds)
        return value.formatted(date: .omitted, time: .shortened)
    }

    private func secondsSinceStart(of value: Date) -> Double {
        let start = calendar.startOfDay(for: date)
        return min(86_400, max(0, value.timeIntervalSince(start)))
    }

    private func timelineColor(for category: ActivityCategory) -> Color {
        categoryColors[category]?.color ?? category.defaultTimelineColor
    }
}

@MainActor
private final class TimelineHoverState: ObservableObject {
    @Published var session: ActivitySession?
    @Published var x: CGFloat = 0
    @Published var width: CGFloat = 0
}

private struct TimelineTooltip: View {
    let session: ActivitySession

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(session.displayTitle)
                .font(.caption.bold())
                .lineLimit(2)
            Text("\(session.appName) • \(session.category.rawValue)")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(timeText(session.startedAt))–\(timeText(session.endedAt)) • \(DurationText.compact(session.duration))")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .frame(width: 250, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.secondary.opacity(0.2))
        }
        .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

private extension ActivityCategory {
    var defaultTimelineColor: Color {
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

private extension CategoryColorValue {
    init(color: Color) {
        let resolved = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        self.init(
            red: Double(resolved.redComponent),
            green: Double(resolved.greenComponent),
            blue: Double(resolved.blueComponent),
            opacity: Double(resolved.alphaComponent)
        )
    }

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }
}

private extension ActivityStore {
    func timelineColor(for category: ActivityCategory) -> Color {
        categoryColors[category]?.color ?? category.defaultTimelineColor
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
