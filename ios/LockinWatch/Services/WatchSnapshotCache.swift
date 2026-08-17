import Foundation

/// Where the watch app leaves state for the complication to find.
///
/// The complication runs in its own extension process and gets no WatchConnectivity
/// callbacks of its own, so the app has to hand it something. This is that something:
/// one JSON blob in the watch's App Group defaults.
///
/// Note the App Group container **does not cross the iPhone/Watch boundary** — the
/// identifier string is the same on both platforms but they are two different
/// containers. Nothing the phone writes to its group is readable here. That is exactly
/// why `PhoneSyncService` exists.
enum WatchSnapshotCache {

    private static let key = "lockin.watch.snapshot"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: WatchAppGroup.identifier) ?? .standard
    }

    static func write(_ payload: WatchSyncPayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: key)
    }

    static func read() -> WatchSyncPayload? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WatchSyncPayload.self, from: data)
    }
}

enum WatchAppGroup {
    /// Must match the App Group capability on BOTH watch targets — the Watch App and
    /// the watch Widget Extension. Same string as `AppGroup.identifier` on the phone,
    /// different container. Change it to your own team's group before the first build.
    static let identifier = "group.com.yourname.lockin"
}
