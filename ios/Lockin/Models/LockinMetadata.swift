import AlarmKit
import Foundation

/// Payload AlarmKit carries from the scheduled alarm through to the Live Activity
/// and the App Intent that runs when the user taps the secondary button.
///
/// `AlarmMetadata` requires `Codable & Hashable & Sendable`. Keep this tiny — it is
/// serialised into the alarm record and crosses into the widget extension process.
struct LockinMetadata: AlarmMetadata {
    let commitmentID: UUID
    let title: String
    let proofKindRaw: String

    init(commitment: Commitment) {
        self.commitmentID = commitment.id
        self.title = commitment.title
        self.proofKindRaw = commitment.proofKind.rawValue
    }

    var proofKind: Commitment.ProofKind {
        Commitment.ProofKind(rawValue: proofKindRaw) ?? .photo
    }
}
