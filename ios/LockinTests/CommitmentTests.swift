import XCTest

/// Tests for the streak and occurrence arithmetic in `Commitment`.
///
/// These exist because this is the one part of the app that cannot be checked by looking
/// at it. A streak bug does not crash, does not log, and does not show up in a screen
/// recording — it takes a fortnight of real use to notice, and by then the number the
/// paywall leans on has already been lying to people.
///
/// Every function under test takes its clock as an argument, so nothing here depends on
/// when CI happens to run. If you add a function that reads `Date()` internally, add the
/// injection point at the same time or it becomes untestable.
final class CommitmentTests: XCTestCase {

    private let calendar = Calendar.current

    // MARK: - Fixtures

    /// A wall-clock time on a day relative to today. Built from components rather than by
    /// adding seconds, so a daylight-saving boundary inside the window cannot shift it.
    private func at(_ hour: Int, _ minute: Int = 0, daysFromToday days: Int = 0) -> Date {
        let day = calendar.date(byAdding: .day, value: days, to: Date())!
        var parts = calendar.dateComponents([.year, .month, .day], from: day)
        parts.hour = hour
        parts.minute = minute
        parts.second = 0
        return calendar.date(from: parts)!
    }

    /// The next occurrence of a given weekday at a given hour, after `date`. Used instead
    /// of hardcoded dates so the weekday tests do not depend on what day CI runs on.
    private func next(weekday: Int, hour: Int, after date: Date) -> Date {
        var parts = DateComponents()
        parts.weekday = weekday
        parts.hour = hour
        parts.minute = 0
        return calendar.nextDate(after: date, matching: parts, matchingPolicy: .nextTime)!
    }

    private func daily(firing date: Date, createdDaysAgo: Int = 30) -> Commitment {
        Commitment(
            title: "Write the essay intro",
            fireDate: date,
            repeats: Commitment.Repeat(weekdays: [1, 2, 3, 4, 5, 6, 7]),
            createdAt: at(0, daysFromToday: -createdDaysAgo)
        )
    }

    private func weekdaysOnly(firing date: Date, createdDaysAgo: Int = 30) -> Commitment {
        Commitment(
            title: "Leave for class",
            fireDate: date,
            repeats: .weekdaysOnly,
            createdAt: at(0, daysFromToday: -createdDaysAgo)
        )
    }

    // MARK: - Streak: counting up

    func testFirstProofStartsTheStreakAtOne() {
        var commitment = daily(firing: at(7))
        commitment.recordProof(at: at(7, 5))

        XCTAssertEqual(commitment.currentStreak, 1)
        XCTAssertEqual(commitment.bestStreak, 1)
    }

    /// The bug this guards: a repeating commitment re-proved after its row is already
    /// ticked used to add one per tap.
    func testProvingTwiceInADayCountsOnce() {
        var commitment = daily(firing: at(7))
        commitment.recordProof(at: at(7, 5))
        commitment.recordProof(at: at(19, 30))

        XCTAssertEqual(commitment.currentStreak, 1)
    }

    func testConsecutiveDaysAccumulate() {
        var commitment = daily(firing: at(7))
        commitment.lastCompletedAt = at(7, 5, daysFromToday: -1)
        commitment.currentStreak = 4

        commitment.recordProof(at: at(7, 5))

        XCTAssertEqual(commitment.currentStreak, 5)
        XCTAssertEqual(commitment.bestStreak, 5)
    }

    /// The whole point of the rewrite: before this, the number only ever went up.
    func testAGapBreaksTheRunAndTheNewOneStartsAtOne() {
        var commitment = daily(firing: at(7))
        commitment.lastCompletedAt = at(7, 5, daysFromToday: -3)
        commitment.currentStreak = 9
        commitment.bestStreak = 9

        commitment.recordProof(at: at(7, 5))

        XCTAssertEqual(commitment.currentStreak, 1, "a broken run restarts, it does not continue")
        XCTAssertEqual(commitment.bestStreak, 9, "the best is a record and has to survive")
    }

    /// A Monday–Friday commitment must not lose its streak over the weekend. This is the
    /// case a naive "was it proved yesterday" check gets wrong every single week.
    func testTheWeekendDoesNotBreakAWeekdayCommitment() {
        let monday = next(weekday: 2, hour: 7, after: at(12, daysFromToday: -14))
        let friday = calendar.date(byAdding: .day, value: -3, to: monday)!

        var commitment = weekdaysOnly(firing: monday)
        commitment.lastCompletedAt = friday.addingTimeInterval(300)
        commitment.currentStreak = 5

        commitment.recordProof(at: monday.addingTimeInterval(300))

        XCTAssertEqual(commitment.currentStreak, 6)
    }

    // MARK: - Streak: breaking without being told

    func testReconcileCountsEveryOccurrenceThatPassedWithoutProof() {
        var commitment = daily(firing: at(7))
        commitment.lastCompletedAt = at(7, 5, daysFromToday: -3)
        commitment.currentStreak = 5

        let missed = commitment.reconcile(now: at(12))

        XCTAssertEqual(missed, 3, "two days ago, yesterday, and this morning")
        XCTAssertEqual(commitment.missCount, 3)
        XCTAssertEqual(commitment.currentStreak, 0)
    }

    func testReconcileDoesNotCountTheSameOccurrenceTwice() {
        var commitment = daily(firing: at(7))
        commitment.lastCompletedAt = at(7, 5, daysFromToday: -3)

        _ = commitment.reconcile(now: at(12))
        let second = commitment.reconcile(now: at(12))

        XCTAssertEqual(second, 0)
        XCTAssertEqual(commitment.missCount, 3)
    }

    /// An alarm ringing right now is not a miss — the user still has the whole nag chain
    /// to answer it.
    func testReconcileLeavesACurrentlyRingingAlarmAlone() {
        let now = at(12)
        var commitment = daily(firing: now.addingTimeInterval(-5 * 60))
        commitment.createdAt = now.addingTimeInterval(-3600)

        let missed = commitment.reconcile(now: now)

        XCTAssertEqual(missed, 0)
        XCTAssertEqual(commitment.currentStreak, 0, "untouched, not reset")
    }

    func testReconcileIsCappedSoALongAbsenceDoesNotWalkForever() {
        var commitment = daily(firing: at(7), createdDaysAgo: 400)
        commitment.lastCompletedAt = at(7, 5, daysFromToday: -400)

        let missed = commitment.reconcile(now: at(12))

        XCTAssertEqual(missed, 30, "capped; past thirty the exact number means nothing")
    }

    // MARK: - Occurrence arithmetic

    func testOccurrencesSkipTheDaysACommitmentDoesNotRepeatOn() {
        let commitment = weekdaysOnly(firing: at(7, daysFromToday: -30))
        let found = commitment.occurrences(
            after: at(0, daysFromToday: -7),
            upTo: at(23, 59, daysFromToday: -1)
        )

        XCTAssertEqual(found.count, 5, "seven days contain five weekdays")
        for date in found {
            XCTAssertTrue(
                Commitment.Repeat.weekdaysOnly.weekdays
                    .contains(calendar.component(.weekday, from: date))
            )
        }
    }

    func testPreviousOccurrenceOfAWeekdayCommitmentSkipsBackOverTheWeekend() {
        let monday = next(weekday: 2, hour: 7, after: at(12, daysFromToday: -14))
        let commitment = weekdaysOnly(firing: monday)

        let previous = commitment.previousOccurrence(before: monday.addingTimeInterval(300))

        XCTAssertNotNil(previous)
        XCTAssertEqual(calendar.component(.weekday, from: previous!), 6, "Friday")
    }

    func testAOneOffHasNoPreviousOccurrenceOnTheDayItFires() {
        let commitment = Commitment(title: "Submit it", fireDate: at(7))
        XCTAssertNil(commitment.previousOccurrence(before: at(9)))
    }

    // MARK: - Rehearsal

    func testARehearsalIsRecognisedAndAnOrdinaryCommitmentIsNot() {
        let rehearsal = Commitment.rehearsal(firing: at(12), proofKind: .photo)
        let ordinary = daily(firing: at(7))

        XCTAssertTrue(rehearsal.isRehearsal)
        XCTAssertFalse(ordinary.isRehearsal)
        XCTAssertEqual(rehearsal.id, Commitment.rehearsalID)
    }

    // MARK: - Storage migration

    /// `reconciledUpTo` was added after people already had commitments on disk. Swift's
    /// synthesised decoding only tolerates a missing key on an Optional — a default value
    /// on a non-Optional does not help, and getting this wrong wipes every commitment on
    /// the device the moment they update.
    func testCommitmentsSavedBeforeReconciledUpToExistedStillDecode() throws {
        let json = Data("""
        [{
          "id": "11111111-1111-1111-1111-111111111111",
          "title": "Write the essay intro",
          "fireDate": 774000000,
          "repeats": { "weekdays": [2, 3, 4, 5, 6] },
          "proofKind": "photo",
          "currentStreak": 3,
          "bestStreak": 7,
          "missCount": 2,
          "isEnabled": true,
          "createdAt": 773000000
        }]
        """.utf8)

        let decoded = try JSONDecoder().decode([Commitment].self, from: json)

        XCTAssertEqual(decoded.count, 1)
        XCTAssertEqual(decoded[0].currentStreak, 3)
        XCTAssertNil(decoded[0].reconciledUpTo)
    }
}
