import Foundation

/// Everything the wrist needs, in one envelope.
///
/// The phone is the only writer. The watch never invents state — it renders this and
/// sends back one of two verbs (`proved`, `dismissed`). One-way state means there is no
/// merge to get wrong after the watch has been out of range for a day, which for an
/// app whose whole value is "the alarm came back" is the only failure mode that matters.
///
/// `LockinMetadata` is deliberately *not* reused here. It conforms to `AlarmMetadata`,
/// which lives in AlarmKit, and AlarmKit has no watchOS surface — the alarm reaches the
/// wrist by system mirroring from the phone, not by running on the watch. Same three
/// facts, different reason to exist.
struct WatchSyncPayload: Codable, Hashable, Sendable {

    /// Every commitment, enabled or not. The watch filters; the phone does not pre-chew.
    var commitments: [Commitment]
    /// Set while an alarm is actually ringing. Nil the rest of the time.
    var ringingCommitmentID: UUID?
    /// Used to drop out-of-order deliveries — WatchConnectivity does not promise order.
    var generatedAt: Date

    init(
        commitments: [Commitment] = [],
        ringingCommitmentID: UUID? = nil,
        generatedAt: Date = .now
    ) {
        self.commitments = commitments
        self.ringingCommitmentID = ringingCommitmentID
        self.generatedAt = generatedAt
    }

    /// Dictionary key both sides agree on. It lives on the shared type so the phone and
    /// the watch cannot disagree about it — a typo here is a silently dead link with no
    /// error anywhere.
    static let transportKey = "payload"

    // MARK: - Derived

    /// The commitment that is ringing right now, if any.
    var ringingCommitment: Commitment? {
        guard let ringingCommitmentID else { return nil }
        return commitments.first { $0.id == ringingCommitmentID }
    }

    /// The soonest thing the user still owes today. This is the complication's headline.
    var nextUp: Commitment? {
        commitments
            .filter { $0.isEnabled && !$0.isDoneToday }
            .compactMap { commitment -> (Commitment, Date)? in
                guard let next = commitment.nextFireDate() else { return nil }
                return (commitment, next)
            }
            .min { $0.1 < $1.1 }?
            .0
    }

    /// One number for a 40mm circle. The streak on the line right now, falling back to
    /// the best live streak when nothing is scheduled — never show a zero we can avoid.
    var currentStreak: Int {
        if let nextUp { return nextUp.currentStreak }
        return commitments.map(\.currentStreak).max() ?? 0
    }
}

/// The two verbs the wrist is allowed to speak, plus a nudge to resend state.
///
/// Sent as a plain dictionary because `WCSession` only takes property-list types.
enum WatchMessage {

    static let actionKey = "action"
    static let commitmentIDKey = "commitmentID"

    enum Action: String, Sendable {
        /// User started the focus timer on the watch. Breaks the nag chain.
        case proved
        /// User bailed from the wrist. Feeds the nag chain exactly like the phone's
        /// "I'm not doing it" button — the wrist is not a softer escape hatch.
        case dismissed
        /// Watch just woke up and wants the current state.
        case requestSnapshot
    }

    static func payload(_ action: Action, commitmentID: UUID? = nil) -> [String: Any] {
        var message: [String: Any] = [actionKey: action.rawValue]
        if let commitmentID { message[commitmentIDKey] = commitmentID.uuidString }
        return message
    }

    static func decode(_ message: [String: Any]) -> (action: Action, commitmentID: UUID?)? {
        guard let raw = message[actionKey] as? String,
              let action = Action(rawValue: raw) else { return nil }
        let id = (message[commitmentIDKey] as? String).flatMap(UUID.init(uuidString:))
        return (action, id)
    }
}

extension Commitment {

    /// The next moment this will actually ring, counting from `reference` forward.
    ///
    /// Lives here rather than on `Commitment` itself because it is only ever needed by
    /// things that have to *rank* commitments — the wrist list and the complication.
    /// The phone always knows what is next because AlarmKit is holding the schedule.
    func nextFireDate(after reference: Date = .now) -> Date? {
        let calendar = Calendar.current

        guard repeats.isRecurring else {
            // One-off: the stored date is the answer, unless it has already gone by.
            return fireDate > reference ? fireDate : nil
        }

        return repeats.weekdays
            .compactMap { weekday -> Date? in
                var components = DateComponents()
                components.weekday = weekday
                components.hour = hour
                components.minute = minute
                return calendar.nextDate(
                    after: reference,
                    matching: components,
                    matchingPolicy: .nextTime
                )
            }
            .min()
    }
}
