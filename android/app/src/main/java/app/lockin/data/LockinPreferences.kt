package app.lockin.data

import android.content.Context
import android.content.SharedPreferences
import androidx.core.content.edit
import java.util.UUID

/**
 * The small, scalar state that does not belong in `commitments.json`.
 *
 * Mirrors iOS's use of `UserDefaults` / `@AppStorage` / `PendingProof`. SharedPreferences
 * rather than DataStore on purpose: [AlarmService][app.lockin.alarm.AlarmService] and the
 * broadcast receivers need to read the nag counter *synchronously*, inside a receiver's
 * short execution window, and a suspending read there is a race waiting to happen.
 */
class LockinPreferences private constructor(context: Context) {

    private val prefs: SharedPreferences =
        context.applicationContext.getSharedPreferences("lockin", Context.MODE_PRIVATE)

    // MARK: - Onboarding

    var hasOnboarded: Boolean
        get() = prefs.getBoolean(KEY_ONBOARDED, false)
        set(value) = prefs.edit { putBoolean(KEY_ONBOARDED, value) }

    /**
     * We ask for the battery-optimisation exemption exactly once, after the first
     * commitment is created. Nagging the user about *permissions* would be an ironic way
     * to lose them.
     */
    var hasAskedBatteryExemption: Boolean
        get() = prefs.getBoolean(KEY_ASKED_BATTERY, false)
        set(value) = prefs.edit { putBoolean(KEY_ASKED_BATTERY, value) }

    // MARK: - Pending proof
    //
    // Hand-off between the alarm process and the app, same idea as iOS's PendingProof:
    // one id parked in defaults, read and cleared when the app comes to the foreground.
    // Deliberately dumb.

    fun setPendingProof(commitmentId: UUID) {
        prefs.edit { putString(KEY_PENDING_PROOF, commitmentId.toString()) }
    }

    /**
     * Read without consuming. Only the diagnostics screen wants this: a debug view that
     * clears the hand-off it was opened to explain would destroy the evidence it exists
     * to show, and the bug would vanish the moment anyone looked at it.
     */
    fun peekPendingProof(): UUID? {
        val raw = prefs.getString(KEY_PENDING_PROOF, null) ?: return null
        return runCatching { UUID.fromString(raw) }.getOrNull()
    }

    fun takePendingProof(): UUID? {
        val raw = prefs.getString(KEY_PENDING_PROOF, null) ?: return null
        prefs.edit { remove(KEY_PENDING_PROOF) }
        return runCatching { UUID.fromString(raw) }.getOrNull()
    }

    // MARK: - Nag counters
    //
    // iOS keeps these in memory on AlarmService. Android cannot: the app process is
    // routinely killed between two rings two minutes apart, and an in-memory counter
    // would reset to zero every time — turning "max 5 nags" into "nags forever", which
    // is the single worst bug this app could ship. So they live on disk.

    fun nagCount(commitmentId: UUID): Int = prefs.getInt(nagKey(commitmentId), 0)

    fun setNagCount(commitmentId: UUID, count: Int) {
        prefs.edit { putInt(nagKey(commitmentId), count) }
    }

    fun clearNagCount(commitmentId: UUID) {
        prefs.edit { remove(nagKey(commitmentId)) }
    }

    private fun nagKey(commitmentId: UUID) = "nag.$commitmentId"

    companion object {
        private const val KEY_ONBOARDED = "hasOnboarded"
        private const val KEY_ASKED_BATTERY = "hasAskedBatteryExemption"
        private const val KEY_PENDING_PROOF = "lockin.pendingProofCommitmentID"

        @Volatile
        private var instance: LockinPreferences? = null

        fun get(context: Context): LockinPreferences =
            instance ?: synchronized(this) {
                instance ?: LockinPreferences(context).also { instance = it }
            }
    }
}
