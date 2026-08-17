import SwiftUI
import WidgetKit

@main
struct LockinWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        LockinComplication()
    }
}

/// The watch face / Smart Stack face of Lockin.
///
/// This is the second reason the watch target earns its place. A mirrored AlarmKit alarm
/// only exists while it is ringing; the complication is the part of the product that is
/// visible for the other 23 hours. It answers one question — *what did I promise, and
/// how much am I about to lose* — with a glance and no taps.
///
/// It reads `WatchSnapshotCache`, never WatchConnectivity. Widget extensions get no
/// session callbacks of their own; the Watch App writes the cache and calls
/// `WidgetCenter.shared.reloadAllTimelines()`, which is what actually refreshes this.
struct LockinComplication: Widget {

    private let kind = "LockinComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next commitment")
        .description("What you said you'd start, and the streak riding on it.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner
        ])
    }
}

// MARK: - Timeline

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let title: String?
    let fireDate: Date?
    let streak: Int

    static let placeholder = ComplicationEntry(
        date: .now,
        title: "Write the thesis intro",
        fireDate: .now.addingTimeInterval(3600),
        streak: 7
    )

    static let empty = ComplicationEntry(
        date: .now,
        title: nil,
        fireDate: nil,
        streak: 0
    )
}

struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> ComplicationEntry {
        .placeholder
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(context.isPreview ? .placeholder : currentEntry())
    }

    /// One entry, and a reload scheduled for the moment the alarm fires.
    ///
    /// Deliberately not a stack of per-minute entries: the countdown is drawn with
    /// `Text(_:style:.relative)`, which the system re-renders for free. Generating a
    /// timeline to animate a clock is how a complication burns its refresh budget and
    /// then goes stale for the rest of the day.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        let entry = currentEntry()

        // Wake up when it fires, or in an hour, whichever comes first.
        let hourFromNow = Date.now.addingTimeInterval(3600)
        let nextReload = [entry.fireDate, hourFromNow]
            .compactMap { $0 }
            .filter { $0 > .now }
            .min() ?? hourFromNow

        completion(Timeline(entries: [entry], policy: .after(nextReload)))
    }

    private func currentEntry() -> ComplicationEntry {
        guard let payload = WatchSnapshotCache.read(), let next = payload.nextUp else {
            return .empty
        }
        return ComplicationEntry(
            date: .now,
            title: next.title,
            fireDate: next.nextFireDate(),
            streak: payload.currentStreak
        )
    }
}

// MARK: - Rendering

struct ComplicationView: View {

    let entry: ComplicationEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:  circular
        case .accessoryRectangular: rectangular
        case .accessoryCorner:    corner
        default:                  rectangular
        }
    }

    /// 40 points across. One glyph and one number — the streak, because that is the
    /// thing the user is afraid of losing.
    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: entry.title == nil ? "lock.open" : "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                if entry.streak > 0 {
                    Text("\(entry.streak)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
            }
        }
        .widgetAccentable()
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(entry.title == nil ? "NOTHING SET" : "YOU SAID")
                    .font(.system(size: 10, weight: .heavy))
            }
            .widgetAccentable()

            Text(entry.title ?? "Add one on your iPhone")
                .font(.system(size: 14, weight: .semibold))
                .lineLimit(entry.streak > 0 ? 1 : 2)

            if let fireDate = entry.fireDate {
                HStack(spacing: 3) {
                    Text(fireDate, style: .relative)
                    if entry.streak > 0 {
                        Text("· \(entry.streak) day streak")
                    }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The corner family draws a glyph in the curve and gets its text from `widgetLabel`,
    /// which the system lays out along the bezel. Anything you put in the body other than
    /// a small glyph gets clipped.
    private var corner: some View {
        Image(systemName: entry.title == nil ? "lock.open" : "lock.fill")
            .font(.title3)
            .widgetAccentable()
            .widgetLabel {
                if let fireDate = entry.fireDate {
                    Text(fireDate, style: .relative)
                } else {
                    Text("Nothing set")
                }
            }
    }
}
