import OSLog

/// The app's own voice in the system log.
///
/// ## Why this exists
/// This project is debugged from a Windows machine against a phone with no debugger
/// attached. The only instrument is the device log — and until now the app said nothing
/// into it, so filtering for `lockin` returned only what iOS says *about* us (StoreKit
/// tasks, launches) and nothing about what our own code decided to do. Which is the only
/// part in question.
///
/// ## Everything here is `.public` on purpose
/// `os_log` redacts interpolated values by default. That is why half of any iOS log reads
/// `<private>` — it is not an error, it is the default, and it makes a log useless for
/// this. Nothing logged below is personal: alarm ids, counts, and state names. The one
/// thing that would be — a commitment's title, which is whatever the user typed about
/// their own life — is never logged.
///
/// ## Every message starts with `NAGG`
/// So a single substring filter in whatever log viewer is to hand catches all of them and
/// nothing else. Do not add a line here that omits it.
enum NaggLog {

    private static let subsystem = "com.r00tlab.lockin"

    /// Scheduling: what got written to AlarmKit and when.
    static let alarms = Logger(subsystem: subsystem, category: "alarms")
    /// The hand-off from a ringing alarm to the proof screen — the path that has been
    /// unreliable on device, and the reason this file exists.
    static let proof = Logger(subsystem: subsystem, category: "proof")
    /// Streaks, misses, and what reconcile decided.
    static let record = Logger(subsystem: subsystem, category: "record")
}
