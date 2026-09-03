import Foundation

/// A thing the user has committed to starting at a specific time.
///
/// The whole product is this one noun. Everything else — alarms, proof, streaks —
/// hangs off it. Keep it small; if you are tempted to add a field, add a screen instead.
struct Commitment: Identifiable, Codable, Hashable, Sendable {

    enum ProofKind: String, Codable, CaseIterable, Sendable {
        /// Photo of the desk / open laptop. Validated on-device first, LLM second.
        case photo
        /// Start a 25 minute focus timer. Alarm only clears when the timer starts.
        case focusTimer
        /// Scan the QR sticker the user put on their desk.
        case deskCode

        var label: String {
            switch self {
            case .photo:      return "Photo of your setup"
            case .focusTimer: return "Start a 25-min focus timer"
            case .deskCode:   return "Scan your desk code"
            }
        }

        var systemImageName: String {
            switch self {
            case .photo:      return "camera.fill"
            case .focusTimer: return "timer"
            case .deskCode:   return "qrcode.viewfinder"
            }
        }
    }

    /// Which days a commitment repeats on. Empty means "once, on `date`".
    struct Repeat: Codable, Hashable, Sendable {
        /// 1 = Sunday ... 7 = Saturday, matching `Calendar.component(.weekday:)`.
        var weekdays: Set<Int>

        static let never = Repeat(weekdays: [])
        static let weekdaysOnly = Repeat(weekdays: [2, 3, 4, 5, 6])

        var isRecurring: Bool { !weekdays.isEmpty }
    }

    let id: UUID
    /// What the user actually has to start. Shown on the full-screen alarm.
    var title: String
    /// Fire time. For recurring commitments only the hour/minute are used.
    var fireDate: Date
    var repeats: Repeat
    var proofKind: ProofKind
    /// Nil until the user proves they started. Reset each occurrence.
    var lastCompletedAt: Date?
    var currentStreak: Int
    var bestStreak: Int
    /// Occurrences the user dismissed without proving. Feeds the weekly excuse report.
    var missCount: Int
    var isEnabled: Bool
    var createdAt: Date
    /// How far `reconcile` has already counted misses.
    ///
    /// Optional so that saved data written before this field existed still decodes —
    /// Swift's synthesised `Codable` only tolerates a missing key on an Optional, a
    /// default value on a non-Optional does not help.
    var reconciledUpTo: Date?
    /// When the user last said out loud they were not doing it.
    ///
    /// Only purpose: stop the app shoving the proof screen back in their face every time
    /// they open it for the rest of the chain. The nagging is the alarm's job; a modal
    /// that will not stay closed is just a broken app.
    var bailedAt: Date?
    /// Every day proof landed, and every day an alarm ran out — one stamp per day.
    ///
    /// The counters above cannot be un-collapsed. `recordProof` bumps a streak and throws
    /// the date away, so a week later nothing can say *which* days those were: no
    /// calendar, no trend, no artefact worth showing anyone. This is the only field here
    /// that is lossy to omit rather than merely absent, which is why it goes in before
    /// there is anything built on top of it. Days before the field existed are gone.
    ///
    /// Optional for the same reason as `reconciledUpTo`.
    var provedDays: [String]?
    var missedDays: [String]?

    init(
        id: UUID = UUID(),
        title: String,
        fireDate: Date,
        repeats: Repeat = .never,
        proofKind: ProofKind = .photo,
        lastCompletedAt: Date? = nil,
        currentStreak: Int = 0,
        bestStreak: Int = 0,
        missCount: Int = 0,
        isEnabled: Bool = true,
        createdAt: Date = .now,
        reconciledUpTo: Date? = nil,
        bailedAt: Date? = nil,
        provedDays: [String]? = nil,
        missedDays: [String]? = nil
    ) {
        self.id = id
        self.title = title
        self.fireDate = fireDate
        self.repeats = repeats
        self.proofKind = proofKind
        self.lastCompletedAt = lastCompletedAt
        self.currentStreak = currentStreak
        self.bestStreak = bestStreak
        self.missCount = missCount
        self.isEnabled = isEnabled
        self.createdAt = createdAt
        self.reconciledUpTo = reconciledUpTo
        self.bailedAt = bailedAt
        self.provedDays = provedDays
        self.missedDays = missedDays
    }

    var hour: Int { Calendar.current.component(.hour, from: fireDate) }
    var minute: Int { Calendar.current.component(.minute, from: fireDate) }

    // MARK: - Rehearsal
    //
    // A rehearsal is a real commitment on a compressed clock: it rings in seconds and its
    // nags are 30 seconds apart instead of two minutes, so the whole chain plays out in
    // under three minutes. It exists for three reasons and they all matter — the user can
    // check the alarm really does beat Silent before they trust it with a 6am, the nag
    // chain can be verified on a device without burning ten minutes a run, and it is the
    // only way to film the mechanic for a 30-second video.
    //
    // Identity is a fixed id rather than a stored flag so that no Codable migration is
    // needed and re-rehearsing reuses the same record instead of piling them up.

    /// Deterministic, so `isRehearsal` needs no extra field on disk.
    static let rehearsalID = UUID(uuidString: "00000000-0000-0000-0000-00000000BEEF")!

    var isRehearsal: Bool { id == Self.rehearsalID }

    static func rehearsal(firing at: Date, proofKind: ProofKind = .focusTimer) -> Commitment {
        Commitment(
            id: rehearsalID,
            title: "Rehearsal — this is what it feels like",
            fireDate: at,
            repeats: .never,
            proofKind: proofKind
        )
    }

    /// True if the user already proved this one today. Used to grey out the row.
    var isDoneToday: Bool {
        guard let lastCompletedAt else { return false }
        return Calendar.current.isDateInToday(lastCompletedAt)
    }

    // MARK: - Occurrences
    //
    // Everything below exists because iOS never tells us the user ignored an alarm.
    // AlarmKit's Stop button does not reach our process and neither does a ring that
    // times out untouched (the same wall that forced the nag chain to be scheduled up
    // front — see `AlarmService`). A miss therefore cannot be *reported*; it has to be
    // *derived*, by comparing the schedule against the last time proof landed.
    //
    // Without this the streak only ever goes up. It counts proofs, not consecutive days:
    // skip a fortnight, prove once, and it climbs to 12. A streak that cannot break is
    // not a streak, it is a tally, and the number on the paywall would be a lie.

    /// Scheduled fire times strictly after `start` and no later than `end`, oldest first.
    ///
    /// Capped, because a phone left in a drawer for a year should not make the app walk
    /// three hundred and sixty-five days on the next launch — and once someone has missed
    /// thirty occurrences, the exact number has stopped meaning anything.
    func occurrences(after start: Date, upTo end: Date, limit: Int = 30) -> [Date] {
        guard start < end else { return [] }

        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        guard repeats.isRecurring else {
            return (fireDate > start && fireDate <= end) ? [fireDate] : []
        }

        var found: [Date] = []
        var cursor = start
        while found.count < limit,
              let next = calendar.nextDate(after: cursor, matching: components, matchingPolicy: .nextTime),
              next <= end {
            if repeats.weekdays.contains(calendar.component(.weekday, from: next)) {
                found.append(next)
            }
            cursor = next
        }
        return found
    }

    /// The scheduled time before the one happening today. This is the link the streak
    /// hangs on: prove today and the run continues only if the previous occurrence was
    /// also proved.
    func previousOccurrence(before date: Date) -> Date? {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: date)
        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        guard repeats.isRecurring else {
            return fireDate < startOfToday ? fireDate : nil
        }

        var cursor = startOfToday
        // Eight days back covers any weekday pattern, including one that fires once a week.
        for _ in 0..<8 {
            guard let previous = calendar.nextDate(
                after: cursor,
                matching: components,
                matchingPolicy: .nextTime,
                direction: .backward
            ) else { return nil }

            if repeats.weekdays.contains(calendar.component(.weekday, from: previous)) {
                return previous
            }
            cursor = previous
        }
        return nil
    }

    // MARK: - Day stamps

    /// A calendar day, as a sortable stamp.
    ///
    /// Deliberately not a `Date`: a stored instant lands on a different day the moment the
    /// user crosses a timezone, and these are only ever compared with each other. Built
    /// from `Calendar.current` so a day here means the same day the rest of the app means.
    static func dayStamp(_ date: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Static, and returning rather than mutating, on purpose: a `mutating` helper taking
    /// `&self.provedDays` is two overlapping exclusive accesses to `self` and does not
    /// compile. Swift is right -- the caller owns the assignment.
    private static func stamped(_ days: [String]?, on date: Date) -> [String] {
        let today = dayStamp(date)
        guard let days else { return [today] }
        return days.contains(today) ? days : days + [today]
    }

    // MARK: - Outcomes

    /// Proof landed.
    ///
    /// Proving twice in one day does not count twice — a repeating commitment that gets
    /// re-proved after the row is already ticked would otherwise inflate the streak by
    /// one per tap.
    mutating func recordProof(at date: Date = .now) {
        provedDays = Self.stamped(provedDays, on: date)
        defer {
            lastCompletedAt = date
            reconciledUpTo = date
            bestStreak = max(bestStreak, currentStreak)
        }

        if let last = lastCompletedAt, Calendar.current.isDate(last, inSameDayAs: date) {
            return
        }

        guard let previous = previousOccurrence(before: date) else {
            // Nothing came before this — first ever, or a one-off. Either way it is day 1.
            currentStreak = 1
            return
        }

        if let last = lastCompletedAt, last >= previous {
            currentStreak += 1
        } else {
            // The run was broken at some point. This proof starts a new one at 1, not 0:
            // the user did the thing today and the number has to say so.
            currentStreak = 1
        }
    }

    /// The user said out loud they were not doing it.
    mutating func recordMiss(at date: Date = .now) {
        missedDays = Self.stamped(missedDays, on: date)
        currentStreak = 0
        missCount += 1
        // Claim the window so `reconcile` does not count this same occurrence again.
        reconciledUpTo = date
        bailedAt = date
    }

    /// Count occurrences that came and went without proof. Call on every foreground.
    ///
    /// `grace` keeps an alarm that is ringing *right now* out of the count — the user
    /// still has the length of the nag chain to answer it, and marking it missed while
    /// it is audible would be both wrong and insulting.
    @discardableResult
    mutating func reconcile(now: Date = .now, grace: TimeInterval = 15 * 60) -> Int {
        let floor = [reconciledUpTo, lastCompletedAt, createdAt].compactMap { $0 }.max() ?? createdAt
        let missed = occurrences(after: floor, upTo: now.addingTimeInterval(-grace))

        reconciledUpTo = now.addingTimeInterval(-grace)
        guard !missed.isEmpty else { return 0 }

        missCount += missed.count
        currentStreak = 0
        return missed.count
    }
}
