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
        createdAt: Date = .now
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
    }

    var hour: Int { Calendar.current.component(.hour, from: fireDate) }
    var minute: Int { Calendar.current.component(.minute, from: fireDate) }

    /// True if the user already proved this one today. Used to grey out the row.
    var isDoneToday: Bool {
        guard let lastCompletedAt else { return false }
        return Calendar.current.isDateInToday(lastCompletedAt)
    }

    mutating func recordProof(at date: Date = .now) {
        lastCompletedAt = date
        currentStreak += 1
        bestStreak = max(bestStreak, currentStreak)
    }

    mutating func recordMiss() {
        currentStreak = 0
        missCount += 1
    }
}
