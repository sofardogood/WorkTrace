import SwiftUI
import Charts
import WTCore
import WTReporting

/// The primary screen: what you actually did, captured automatically.
///
/// It supports two ranges — a single day (with prev/next/Today navigation) and
/// the last 7 days — and organises the data into purpose-based tabs: Overview,
/// Applications, Windows & Screens, Timeline and Trends. A filter bar narrows by
/// app, window-title search and masked/readable titles. All aggregation is done
/// by the unit-tested `WTReporting` models; this view is presentation only.
///
/// WorkTrace's own foreground time is excluded from every summary/chart so the
/// app's control surface never dominates real work; it still appears in the
/// detailed Timeline rows for transparency.
struct ActivityTimelineView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.locale) private var locale

    /// 7-day window of entries ending on `selectedDate`, loaded once per change.
    @State private var entries: [ActivityEntry] = []
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var rangeMode: RangeMode = .day
    @State private var tab: Tab = .overview

    // Filters
    @State private var filterAppName: String?
    @State private var filterQuery: String = ""
    @State private var filterMasking: ActivityFilter.Masking = .all

    private let selfBundleId = Bundle.main.bundleIdentifier
    private let calendar = Calendar.current

    private enum RangeMode: Hashable { case day, week }
    private enum Tab: Hashable { case overview, applications, windows, timeline, trends }
    private enum SummaryKind { case app, window }

    private struct Segment: Identifiable {
        let id = UUID()
        let start: Date
        let end: Date
        let label: String
        let isIdle: Bool
    }

    /// One wedge of a donut chart (composition of a whole).
    private struct Slice: Identifiable {
        let id = UUID()
        let label: String
        let value: TimeInterval
        let color: Color
    }

    private enum TimelineItem: Identifiable {
        case activity(ActivityEntry)
        case idle(start: Date, end: Date)
        var id: String {
            switch self {
            case .activity(let e): return "a-\(e.id ?? 0)-\(e.startAt.timeIntervalSince1970)"
            case .idle(let s, let e): return "i-\(s.timeIntervalSince1970)-\(e.timeIntervalSince1970)"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            navBar
            captureStatus
            filterBar
            tabPicker
            Divider()
            content
        }
        .frame(minWidth: 600, minHeight: 660)
        .task { reload() }
    }

    // MARK: - Header & navigation

    private var header: some View {
        HStack {
            Text("activity.today").font(.title2).bold()
            Spacer()
            Picker("", selection: $rangeMode) {
                Text("activity.range.day").tag(RangeMode.day)
                Text("activity.range.week").tag(RangeMode.week)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            Button("activity.refresh", action: reload)
        }
        .padding([.horizontal, .top])
        .padding(.bottom, 6)
    }

    private var navBar: some View {
        HStack(spacing: 8) {
            Button { step(-1) } label: { Image(systemName: "chevron.left") }
                .help(Text("activity.prevDay"))
            Button("activity.todayButton") { go(to: Date()) }
            Button { step(1) } label: { Image(systemName: "chevron.right") }
                .help(Text("activity.nextDay"))
                .disabled(isSelectedToday)
            Spacer()
            Text(rangeLabel).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var captureStatus: some View {
        if !appState.preferences.activityCaptureEnabled {
            statusBanner("activity.captureOff", systemImage: "pause.circle", tint: .orange)
        } else if !appState.accessibilityGranted {
            statusBanner("activity.titlesOmitted", systemImage: "exclamationmark.triangle", tint: .orange)
        } else {
            statusBanner("activity.capturing", systemImage: "record.circle", tint: .green)
        }
    }

    private func statusBanner(_ key: LocalizedStringKey, systemImage: String, tint: Color) -> some View {
        Label(key, systemImage: systemImage)
            .font(.caption).foregroundStyle(tint)
            .padding(.horizontal).padding(.bottom, 6)
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        HStack(spacing: 8) {
            Picker("activity.filter.app", selection: $filterAppName) {
                Text("activity.filter.allApps").tag(String?.none)
                ForEach(availableApps, id: \.self) { app in
                    Text(app).tag(String?.some(app))
                }
            }
            .labelsHidden().fixedSize()

            Picker("activity.filter.masking", selection: $filterMasking) {
                Text("activity.filter.maskAll").tag(ActivityFilter.Masking.all)
                Text("activity.filter.maskReadable").tag(ActivityFilter.Masking.readableOnly)
                Text("activity.filter.maskMasked").tag(ActivityFilter.Masking.maskedOnly)
            }
            .labelsHidden().fixedSize()

            TextField("activity.filter.search", text: $filterQuery)
                .textFieldStyle(.roundedBorder)

            if filter.isActive {
                Button("activity.filter.reset", action: resetFilters)
            }
        }
        .font(.caption)
        .padding(.horizontal).padding(.bottom, 8)
    }

    private var tabPicker: some View {
        Picker("", selection: $tab) {
            Text("activity.tab.overview").tag(Tab.overview)
            Text("activity.tab.applications").tag(Tab.applications)
            Text("activity.tab.windows").tag(Tab.windows)
            Text("activity.tab.timeline").tag(Tab.timeline)
            Text("activity.tab.trends").tag(Tab.trends)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding([.horizontal, .bottom], 8)
    }

    // MARK: - Content routing

    @ViewBuilder
    private var content: some View {
        if isOutOfRetention {
            ContentUnavailableView("activity.outOfRetention", systemImage: "clock.badge.xmark")
                .frame(maxHeight: .infinity)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    switch tab {
                    case .overview:     overviewTab
                    case .applications: applicationsTab
                    case .windows:      windowsTab
                    case .timeline:     timelineTab
                    case .trends:       trendsTab
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Overview tab

    private var overviewTab: some View {
        VStack(alignment: .leading, spacing: 18) {
            summaryCards
            if scopedWork.isEmpty {
                emptyNote(true)
            } else {
                // Donuts: composition is the point here (share of the whole).
                donut("activity.chart.activeIdle", slices: activeIdleSlices,
                      centerText: activePercentText)
                donut("activity.chart.appShare", slices: appShareSlices)
            }
        }
    }

    private var summaryCards: some View {
        let s = stats
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
            card("activity.summary.active", value: fmt(s.activeTotal), systemImage: "clock")
            card("activity.summary.idle", value: fmt(s.idleTotal), systemImage: "moon.zzz")
            card("activity.summary.switches", value: "\(s.appSwitches)", systemImage: "arrow.left.arrow.right")
            card("activity.summary.topApp", value: label(s.topApp?.label, kind: .app), systemImage: "star")
            card("activity.summary.topWindow", value: label(s.topWindow?.label, kind: .window), systemImage: "macwindow")
            if rangeMode == .week {
                card("activity.summary.dailyAvg", value: fmt(period.dailyAverageActive), systemImage: "chart.bar")
            }
        }
    }

    private func card(_ title: LocalizedStringKey, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            Text(value).font(.title3).bold().monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    /// A donut chart used only where percentage composition is the main point.
    /// `centerText` places a headline value in the hole (e.g. the active share).
    private func donut(_ title: LocalizedStringKey, slices: [Slice],
                       height: CGFloat = 200, centerText: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Chart(slices) { slice in
                SectorMark(
                    angle: .value("Time", slice.value),
                    innerRadius: .ratio(0.62),
                    angularInset: 1.5
                )
                .cornerRadius(3)
                .foregroundStyle(by: .value("Category", slice.label))
            }
            .chartForegroundStyleScale(domain: slices.map(\.label), range: slices.map(\.color))
            .chartLegend(position: .trailing, alignment: .center)
            .chartBackground { _ in
                if let centerText {
                    Text(centerText).font(.headline).bold().monospacedDigit()
                }
            }
            .frame(height: height)
        }
    }

    // MARK: - Applications tab

    private var applicationsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("activity.chart.appUsage").font(.headline)
            let totals = appTotals
            if totals.isEmpty {
                emptyNote(true)
            } else {
                Chart(totals) { total in
                    BarMark(
                        x: .value("Time", total.total / 60),
                        y: .value("App", label(total.label, kind: .app))
                    )
                    .foregroundStyle(color(for: total.label))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("\(fmt(total.total)) · \(percent(total.total))")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .chartYAxis { AxisMarks(preset: .aligned) { AxisValueLabel() } }
                .frame(height: CGFloat(totals.count) * 30 + 20)

                // Optional small donut: share of active time by app.
                donut("activity.chart.appShare", slices: appShareSlices, height: 160)
            }
            selfExcludedNote
        }
    }

    // MARK: - Windows & Screens tab

    private var windowsTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("activity.chart.windowUsage").font(.headline)
            let ranking = ActivitySummarizer.byWindow(scopedWork)
            if ranking.isEmpty {
                emptyNote(true)
            } else {
                let maxTotal = ranking.first?.total ?? 1
                ForEach(ranking.prefix(20)) { usage in
                    windowRow(usage, maxTotal: maxTotal)
                }
            }
        }
    }

    private func windowRow(_ usage: WindowUsage, maxTotal: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                if usage.isMasked {
                    Label("activity.windows.masked", systemImage: "eye.slash")
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                } else {
                    Text(usage.title).font(.subheadline).lineLimit(1)
                }
                Spacer()
                Text(fmt(usage.total)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                if let app = usage.appName {
                    Text(app).font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
                }
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(usage.isMasked ? Color.gray : color(for: usage.appName ?? usage.title))
                        .frame(width: max(2, geo.size.width * fraction(usage.total, of: maxTotal)))
                }
                .frame(height: 6)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Timeline tab (always a single day)

    private var timelineTab: some View {
        let items = timelineItems(filter.apply(dayEntries))
        return VStack(alignment: .leading, spacing: 14) {
            timelineChart(items)
            if items.isEmpty {
                emptyNote(true)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text("activity.details").font(.headline).padding(.bottom, 4)
                    ForEach(items) { item in
                        row(item)
                        Divider()
                    }
                }
            }
            selfExcludedNote
        }
    }

    private func timelineChart(_ items: [TimelineItem]) -> some View {
        let segments: [Segment] = items.compactMap { item in
            switch item {
            case .activity(let e):
                guard e.bundleId != selfBundleId else { return nil }
                return Segment(start: e.startAt, end: e.endAt, label: e.appName ?? "", isIdle: false)
            case .idle(let s, let e):
                return Segment(start: s, end: e, label: "", isIdle: true)
            }
        }
        return VStack(alignment: .leading, spacing: 6) {
            Text("activity.chart.timeline").font(.headline)
            Chart(segments) { seg in
                BarMark(xStart: .value("Start", seg.start), xEnd: .value("End", seg.end),
                        y: .value("Day", ""))
                    .foregroundStyle(seg.isIdle ? Color.gray.opacity(0.25) : color(for: seg.label))
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                    AxisGridLine(); AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis(.hidden)
            .frame(height: 56)
        }
    }

    @ViewBuilder
    private func row(_ item: TimelineItem) -> some View {
        switch item {
        case .activity(let entry): activityRow(entry)
        case .idle(let start, let end): idleRow(start: start, end: end)
        }
    }

    private func activityRow(_ entry: ActivityEntry) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(appLabel(entry)).font(.headline)
                    if entry.isMasked {
                        Image(systemName: "eye.slash")
                            .font(.caption2).foregroundStyle(.secondary)
                            .help(Text("activity.maskedHelp"))
                    }
                }
                Text(titleLabel(entry)).font(.subheadline)
                    .foregroundStyle(entry.windowTitle == nil ? .secondary : .primary)
                Text("\(DayHelpers.time(entry.startAt)) – \(DayHelpers.time(entry.endAt))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(fmt(entry.duration)).monospacedDigit()
        }
        .padding(.vertical, 4)
    }

    private func idleRow(start: Date, end: Date) -> some View {
        HStack {
            Label("activity.idle", systemImage: "moon.zzz")
                .font(.caption).foregroundStyle(.secondary)
            Text("\(DayHelpers.time(start)) – \(DayHelpers.time(end))")
                .font(.caption).foregroundStyle(.tertiary)
            Spacer()
            Text(fmt(end.timeIntervalSince(start)))
                .font(.caption).monospacedDigit().foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Trends tab

    private var trendsTab: some View {
        let days = period.days
        return VStack(alignment: .leading, spacing: 18) {
            trendChart("activity.trends.active", days: days, color: .green) { $0.stats.activeTotal / 60 }
            trendChart("activity.trends.idle", days: days, color: .gray) { $0.stats.idleTotal / 60 }
            trendChart("activity.trends.switches", days: days, color: .orange) { Double($0.stats.appSwitches) }
            trendTable(days)
        }
    }

    private func trendChart(_ title: LocalizedStringKey, days: [DayActivity], color: Color,
                            value: @escaping (DayActivity) -> Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Chart(days) { day in
                LineMark(x: .value("Day", day.date, unit: .day), y: .value("Value", value(day)))
                    .foregroundStyle(color)
                PointMark(x: .value("Day", day.date, unit: .day), y: .value("Value", value(day)))
                    .foregroundStyle(color)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine(); AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 120)
        }
    }

    /// Per-day table: active time, top app, and the change from the previous day.
    private func trendTable(_ days: [DayActivity]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("activity.trends.perDay").font(.headline).padding(.bottom, 4)
            ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                let prev = index > 0 ? days[index - 1].stats.activeTotal : nil
                HStack {
                    Text(day.date.formatted(.dateTime.month(.abbreviated).day()))
                        .frame(width: 64, alignment: .leading)
                    Text(label(day.stats.topApp?.label, kind: .app))
                        .font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Text(fmt(day.stats.activeTotal)).monospacedDigit()
                    diffBadge(current: day.stats.activeTotal, previous: prev)
                }
                .padding(.vertical, 3)
                Divider()
            }
        }
    }

    @ViewBuilder
    private func diffBadge(current: TimeInterval, previous: TimeInterval?) -> some View {
        if let previous {
            let delta = current - previous
            let up = delta >= 0
            Text("\(up ? "+" : "−")\(fmt(abs(delta)))")
                .font(.caption2).monospacedDigit()
                .foregroundStyle(delta == 0 ? Color.secondary : (up ? Color.green : Color.red))
                .frame(width: 72, alignment: .trailing)
        } else {
            Color.clear.frame(width: 72, height: 1)
        }
    }

    @ViewBuilder
    private var selfExcludedNote: some View {
        if entries.contains(where: { $0.bundleId == selfBundleId }) {
            Text("activity.selfExcluded").font(.caption2).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func emptyNote(_ show: Bool) -> some View {
        if show {
            Text("activity.noneForRange").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    // MARK: - Derived data

    private var filter: ActivityFilter {
        ActivityFilter(
            appName: filterAppName,
            titleQuery: filterQuery.isEmpty ? nil : filterQuery,
            masking: filterMasking
        )
    }

    /// Entries for the selected single day (within the loaded window).
    private var dayEntries: [ActivityEntry] {
        let (start, end) = DayHelpers.dayBounds(for: selectedDate, calendar: calendar)
        return entries.filter { $0.startAt >= start && $0.startAt < end }
    }

    /// Entries in scope for the current range, after filtering.
    private var scopedEntries: [ActivityEntry] {
        filter.apply(rangeMode == .day ? dayEntries : entries)
    }

    /// Scoped entries with WorkTrace's own foreground time removed.
    private var scopedWork: [ActivityEntry] {
        scopedEntries.filter { $0.bundleId != selfBundleId }
    }

    private var stats: ActivityStats {
        ActivityAnalytics.stats(for: scopedEntries, idleThreshold: idleThreshold,
                                excludingBundleId: selfBundleId)
    }

    private var period: PeriodSummary {
        ActivityAnalytics.period(entries: filter.apply(entries), days: 7, endingOn: selectedDate,
                                 idleThreshold: idleThreshold, excludingBundleId: selfBundleId,
                                 calendar: calendar)
    }

    private var appTotals: [ActivityTotal] { ActivitySummarizer.byApp(scopedWork) }

    /// Active vs idle as donut wedges.
    private var activeIdleSlices: [Slice] {
        [
            Slice(label: String(localized: "activity.legend.active"),
                  value: stats.activeTotal, color: .green),
            Slice(label: String(localized: "activity.legend.idle"),
                  value: stats.idleTotal, color: .gray),
        ]
    }

    /// The share of recorded time that was active, e.g. "72%", for the donut hole.
    private var activePercentText: String {
        let total = stats.activeTotal + stats.idleTotal
        guard total > 0 else { return "—" }
        return "\(Int((stats.activeTotal / total * 100).rounded()))%"
    }

    /// App usage share: the top 5 apps plus an aggregated "Other" wedge.
    private var appShareSlices: [Slice] {
        let totals = appTotals
        var slices = totals.prefix(5).map {
            Slice(label: label($0.label, kind: .app), value: $0.total, color: color(for: $0.label))
        }
        let otherTotal = totals.dropFirst(5).reduce(0) { $0 + $1.total }
        if otherTotal > 0 {
            slices.append(Slice(label: String(localized: "activity.chart.other"),
                                value: otherTotal, color: .secondary))
        }
        return slices
    }

    private var availableApps: [String] {
        Array(Set(entries.compactMap { $0.appName }.filter { !$0.isEmpty })).sorted()
    }

    private var idleThreshold: TimeInterval {
        TimeInterval(appState.preferences.idleThresholdSeconds)
    }

    private func timelineItems(_ source: [ActivityEntry]) -> [TimelineItem] {
        let sorted = source.sorted { $0.startAt < $1.startAt }
        var items: [TimelineItem] = []
        var previousEnd: Date?
        for entry in sorted {
            if let previousEnd, entry.startAt.timeIntervalSince(previousEnd) >= idleThreshold {
                items.append(.idle(start: previousEnd, end: entry.startAt))
            }
            items.append(.activity(entry))
            previousEnd = entry.endAt
        }
        return items
    }

    // MARK: - Retention & range state

    /// True when the selected single day precedes the retention window, so its
    /// logs have been purged and cannot be shown.
    private var isOutOfRetention: Bool {
        guard rangeMode == .day,
              let cutoff = appState.preferences.retentionPeriod.cutoff(now: Date(), calendar: calendar)
        else { return false }
        return selectedDate < cutoff
    }

    private var isSelectedToday: Bool {
        calendar.isDate(selectedDate, inSameDayAs: Date())
    }

    private var rangeLabel: String {
        if rangeMode == .day {
            return selectedDate.formatted(date: .complete, time: .omitted)
        }
        let start = calendar.date(byAdding: .day, value: -6, to: selectedDate) ?? selectedDate
        let f = Date.FormatStyle.dateTime.month(.abbreviated).day()
        return "\(start.formatted(f)) – \(selectedDate.formatted(f))"
    }

    // MARK: - Actions

    private func step(_ days: Int) {
        go(to: calendar.date(byAdding: .day, value: days, to: selectedDate) ?? selectedDate)
    }

    private func go(to date: Date) {
        let start = calendar.startOfDay(for: date)
        // Never navigate into the future.
        selectedDate = min(start, calendar.startOfDay(for: Date()))
        reload()
    }

    private func resetFilters() {
        filterAppName = nil
        filterQuery = ""
        filterMasking = .all
    }

    // MARK: - Formatting & labels

    private func fmt(_ seconds: TimeInterval) -> String {
        DayHelpers.duration(seconds, locale: locale)
    }

    private func percent(_ value: TimeInterval) -> String {
        let total = stats.activeTotal
        guard total > 0 else { return "0%" }
        return "\(Int((value / total * 100).rounded()))%"
    }

    private func fraction(_ value: TimeInterval, of maxValue: TimeInterval) -> Double {
        maxValue > 0 ? value / maxValue : 0
    }

    private func color(for label: String) -> Color {
        guard !label.isEmpty else { return .gray }
        let palette: [Color] = [.blue, .green, .orange, .purple, .pink,
                                .teal, .indigo, .red, .mint, .cyan]
        var hash = 5381
        for byte in label.utf8 { hash = (hash &* 33) &+ Int(byte) }
        return palette[abs(hash) % palette.count]
    }

    private func appLabel(_ entry: ActivityEntry) -> String {
        entry.appName ?? String(localized: "activity.unknownApp")
    }

    private func titleLabel(_ entry: ActivityEntry) -> String {
        switch entry.privacyLevel {
        case .full:        return entry.windowTitle ?? String(localized: "activity.noTitle")
        case .maskedTitle: return String(localized: "activity.titleHidden")
        case .timeOnly:    return String(localized: "activity.private")
        case .excluded:    return ""
        }
    }

    private func label(_ raw: String?, kind: SummaryKind) -> String {
        guard let raw, !raw.isEmpty else {
            switch kind {
            case .app:    return String(localized: "activity.unknownApp")
            case .window: return String(localized: "activity.noTitleOrPrivate")
            }
        }
        return raw
    }

    // MARK: - Load

    private func reload() {
        // Load a 7-day window ending on the selected day so both the day and the
        // week views draw from a single fetch.
        let dayStart = calendar.startOfDay(for: selectedDate)
        let start = calendar.date(byAdding: .day, value: -6, to: dayStart) ?? dayStart
        let end = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        entries = (try? appState.activity.entries(from: start, to: end)) ?? []
        appState.refreshAccessibility()
    }
}
