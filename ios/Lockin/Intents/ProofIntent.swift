import AppIntents
import Foundation

/// Runs when the user taps "I'm starting" on the full-screen alarm, the Lock Screen,
/// or the Dynamic Island.
///
/// It does exactly one thing: mark which commitment needs proof and open the app.
/// Resist putting logic here — the intent runs in a constrained context and anything
/// slow makes the button feel broken at the exact moment the user is least patient.
struct ProofIntent: LiveActivityIntent {

    // `let`, not `var`. AppIntent declares these as get-only requirements, and under
    // Swift 6 strict concurrency a mutable static is nonisolated shared state — an
    // error, not a warning. Every App Intent in the project must follow this.
    static let title: LocalizedStringResource = "Start now"
    static let description = IntentDescription("Opens Nagg so you can prove you started.")

    /// Live Activity intents must opt in to foregrounding the app.
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Commitment")
    var commitmentID: String

    init() {}

    init(commitmentID: String) {
        self.commitmentID = commitmentID
    }

    func perform() async throws -> some IntentResult {
        PendingProof.shared.set(commitmentID)
        return .result()
    }
}

/// Hand-off between the intent (which may run in the widget extension) and the app.
/// Deliberately dumb: one id in shared defaults, read and cleared on launch.
struct PendingProof {
    static let shared = PendingProof()

    private let key = "lockin.pendingProofCommitmentID"
    private var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    func set(_ commitmentID: String) {
        defaults.set(commitmentID, forKey: key)
    }

    func take() -> UUID? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        defaults.removeObject(forKey: key)
        return UUID(uuidString: raw)
    }
}

enum AppGroup {
    /// Must match the App Group capability on BOTH the app and the widget target.
    /// Change this to your own team's group before the first build.
    static let identifier = "group.com.r00tlab.lockin"
}
