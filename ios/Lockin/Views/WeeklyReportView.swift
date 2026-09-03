import SwiftUI

/// The report onboarding and the paywall both promise: "every excuse you made".
///
/// It existed as a sentence in two pieces of marketing copy and nowhere in the app. That
/// is worse than not promising it — a subscriber who goes looking for the thing they paid
/// for and cannot find it asks for a refund, and is right to.
///
/// ## What it can honestly show
/// The store keeps aggregates, not a diary: a current streak, a best, a miss count, and
/// the last time proof landed. So this screen shows exactly that and does not fake a
/// seven-day grid it has no data for. If per-day history is wanted later, it has to be
/// recorded first — inventing squares from a total would be a chart that lies.
///
/// ## Tone
/// Blunt, never cruel. The product's whole position is that it is the one app that does
/// not let you off, and a report that congratulates you for a zero-day streak throws that
/// away. But it is a study app, not a punishment — no shame language, no red numbers on
/// a day someone did fine.
struct WeeklyReportView: View {

    let store: CommitmentStore
    let onFinish: () -> Void

    private var commitments: [Commitment] { store.visibleCommitments }

    private var totalExcuses: Int {
        commitments.reduce(0) { $0 + $1.missCount }
    }

    private var bestStreak: Int {
        commitments.reduce(0) { max($0, $1.bestStreak) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("The receipts").naggLabel().padding(.bottom, 10)

                Text(headline)
                    .font(Nagg.sans(26, .medium))
                    .lineSpacing(2)
                    .foregroundStyle(Nagg.ink)

                if commitments.isEmpty {
                    Text("Nothing to report yet. Add a commitment and this fills itself in.")
                        .font(Nagg.sans(15))
                        .lineSpacing(4)
                        .foregroundStyle(Nagg.ink2)
                        .padding(.top, 12)
                } else {
                    Text(subhead)
                        .font(Nagg.sans(15))
                        .lineSpacing(4)
                        .foregroundStyle(Nagg.ink2)
                        .padding(.top, 10)

                    calendar.padding(.top, 24)

                    VStack(spacing: 8) {
                        ForEach(commitments) { commitment in
                            row(commitment)
                        }
                    }
                    .padding(.top, 24)
                }

                Button("Close") { onFinish() }
                    .buttonStyle(NaggGhostButton())
                    .padding(.top, 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
            .padding(.bottom, 24)
        }
        .naggGround()
        .presentationDragIndicator(.visible)
    }

    // MARK: - Copy
    //
    // The headline is the one number the user did not want to see. Zero excuses is worth
    // saying plainly rather than dressing up — the number is the compliment.

    private var headline: String {
        if commitments.isEmpty { return "Nothing on the record." }
        if totalExcuses == 0 { return "Zero excuses on the record." }
        if totalExcuses == 1 { return "One excuse on the record." }
        return "\(totalExcuses) excuses on the record."
    }

    private var subhead: String {
        if totalExcuses == 0 {
            return bestStreak > 0
                ? "Best run so far: \(bestStreak) day\(bestStreak == 1 ? "" : "s"). Nagg has nothing on you."
                : "Nothing missed yet. The first week is the easy one."
        }
        return "Every one of these is an alarm that rang and a thing that did not get started."
    }

    // MARK: - The record

    /// Five weeks of squares, oldest first, today in the bottom right.
    ///
    /// Deliberately not aligned to weekday columns: that needs the locale's first weekday
    /// and a leading run of blanks, and every one of those is a way to be off by one on
    /// somebody else's calendar. Thirty-five days in rows of seven says the same thing.
    ///
    /// Sizes are fixed rather than flexible. 7 x 26 plus the gaps is 218pt, which fits the
    /// narrowest iPhone with room to spare, and a grid that cannot stretch cannot swallow
    /// the page the way the stats strip did.
    private var calendar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("last five weeks").naggLabel()

            VStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { week in
                    HStack(spacing: 6) {
                        ForEach(0..<7, id: \.self) { day in
                            square(lastDays[week * 7 + day])
                        }
                    }
                }
            }

            HStack(spacing: 14) {
                key(Nagg.go, "started")
                key(Nagg.alarm, "excuse")
                key(Nagg.line, "nothing due")
            }
            .padding(.top, 2)

            if provedSet.isEmpty && missedSet.isEmpty && (bestStreak > 0 || totalExcuses > 0) {
                // Upgraders have counters but no day history: the app only started writing
                // days down in this version. Saying so beats an empty grid next to a
                // streak of nine, which just reads as a bug.
                Text("The day-by-day record starts with this update. The counts above go further back.")
                    .font(Nagg.sans(12))
                    .lineSpacing(3)
                    .foregroundStyle(Nagg.ink3)
                    .padding(.top, 4)
            }
        }
    }

    private var provedSet: Set<String> { Set(commitments.flatMap { $0.provedDays ?? [] }) }
    private var missedSet: Set<String> { Set(commitments.flatMap { $0.missedDays ?? [] }) }

    /// 35 day stamps ending today. Padded rather than trimmed so the grid is never ragged.
    private var lastDays: [String] {
        let cal = Foundation.Calendar.current
        let today = Date()
        let stamps = (0..<35).reversed().compactMap { offset in
            cal.date(byAdding: .day, value: -offset, to: today).map(Commitment.dayStamp)
        }
        return stamps.count == 35 ? stamps : stamps + Array(repeating: "", count: 35 - stamps.count)
    }

    private func square(_ stamp: String) -> some View {
        let started = provedSet.contains(stamp)
        // Starting wins over bailing on the same day: you may have let one alarm run out
        // and still got to the desk for another, and the square should say the better one.
        let excuse = !started && missedSet.contains(stamp)
        return RoundedRectangle(cornerRadius: 4)
            .fill(started ? Nagg.go : (excuse ? Nagg.alarm : Nagg.line))
            .frame(width: 26, height: 26)
    }

    private func key(_ colour: Color, _ label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(colour).frame(width: 9, height: 9)
            Text(label).naggLabel()
        }
    }

    // MARK: - Rows

    private func row(_ commitment: Commitment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(commitment.title)
                .font(Nagg.sans(15, .medium))
                .foregroundStyle(Nagg.ink)

            HStack(spacing: 0) {
                figure("\(commitment.currentStreak)", "now", tint: commitment.currentStreak > 0 ? Nagg.go : Nagg.ink3)
                figure("\(commitment.bestStreak)", "best", tint: Nagg.ink)
                figure("\(commitment.missCount)", "excuses", tint: commitment.missCount > 0 ? Nagg.alarm : Nagg.ink3)
            }

            Text(lastProved(commitment))
                .font(Nagg.mono(11, .regular))
                .monospacedDigit()
                .foregroundStyle(Nagg.ink3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .naggCard()
    }

    private func figure(_ value: String, _ label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).naggFigure(20).foregroundStyle(tint)
            Text(label).naggLabel()
        }
        .frame(maxWidth: .infinity)
    }

    private func lastProved(_ commitment: Commitment) -> String {
        guard let last = commitment.lastCompletedAt else { return "never proved" }
        if Calendar.current.isDateInToday(last) { return "proved today" }
        if Calendar.current.isDateInYesterday(last) { return "proved yesterday" }
        return "last proved \(last.formatted(date: .abbreviated, time: .omitted))"
    }
}
