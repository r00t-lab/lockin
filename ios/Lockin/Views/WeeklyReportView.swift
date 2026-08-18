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

    @Environment(CommitmentStore.self) private var store
    @Environment(\.dismiss) private var dismiss

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

                    VStack(spacing: 8) {
                        ForEach(commitments) { commitment in
                            row(commitment)
                        }
                    }
                    .padding(.top, 24)
                }

                Button("Close") { dismiss() }
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
                ? "Best run so far: \(bestStreak) days. Nagg has nothing on you."
                : "Nothing missed yet. The first week is the easy one."
        }
        return "Every one of these is an alarm that rang and a thing that did not get started."
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
