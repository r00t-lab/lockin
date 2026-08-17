package app.lockin.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import app.lockin.MainActivity
import app.lockin.data.LockinPreferences
import app.lockin.model.Commitment
import app.lockin.model.Weekdays
import java.time.Instant
import java.time.LocalTime
import java.time.ZoneId
import java.util.UUID

/**
 * Owns every interaction with [AlarmManager]. The Android counterpart of
 * `AlarmService.swift`, deliberately named the same.
 *
 * (Note the neighbours: this class schedules. [AlarmRingService] is the actual
 * `android.app.Service` that makes noise once an alarm fires. Two different jobs, and
 * only one of them is a Service in the framework sense.)
 *
 * ## The one mechanic that matters
 * Android will always let the user silence a ringing alarm, and any attempt to prevent
 * that would be removed from Play — the same constraint AlarmKit imposes on iOS. So
 * "you can't dismiss it without proof" is not enforced by removing the button. It is
 * enforced by the **nag loop**:
 *
 *   1. The commitment alarm fires via [AlarmManager.setAlarmClock], which is exempt from
 *      Doze and app-standby, and rings on the alarm stream — through Do Not Disturb.
 *   2. "I'm starting" → opens the app straight to the proof screen.
 *   3. "Dismiss" silences *this* ring, then [scheduleNag] puts another alarm
 *      [NAG_INTERVAL_MILLIS] later. Up to [MAX_NAGS] times.
 *   4. Proof recorded → [clearNags] cancels the whole chain.
 *
 * This is the same shape as Alarmy's anti-cheat, which is the moat on a $500K/mo app.
 * Do not water it down: if the nag loop is polite, the product has no reason to exist.
 *
 * ## Why setAlarmClock and not setExactAndAllowWhileIdle
 * `setAlarmClock` is the only API the platform treats as a user-visible alarm clock. It
 * gets the strongest Doze exemption available, it puts the alarm icon in the status bar,
 * and — the part that actually matters here — it grants the app a short foreground-service
 * start exemption when it fires, which is how [AlarmRingService] is allowed to start from
 * a broadcast receiver on Android 12+. `setExactAndAllowWhileIdle` gets none of that and
 * is rate-limited to roughly once every 9 minutes per app, which would quietly break the
 * 2-minute nag chain.
 */
class AlarmService private constructor(context: Context) {

    private val appContext = context.applicationContext
    private val alarmManager = appContext.getSystemService(AlarmManager::class.java)
    private val prefs = LockinPreferences.get(appContext)

    // MARK: - Permission state

    /**
     * On API 33+ `USE_EXACT_ALARM` is permanently granted, so this is always true. On
     * 31/32 the auto-granted `SCHEDULE_EXACT_ALARM` can be revoked by the user, and on
     * 26–30 no permission exists. See the manifest comment for the full matrix.
     */
    fun canScheduleExact(): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) alarmManager.canScheduleExactAlarms()
        else true

    /**
     * Only reachable on API 31/32 — on 33+ there is nothing to request. Returns false if
     * there is no screen to send the user to, so the caller can skip the UI entirely.
     */
    fun requestExactAlarmPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || canScheduleExact()) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) return false

        val intent = Intent(
            Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
            android.net.Uri.parse("package:${appContext.packageName}"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return runCatching { appContext.startActivity(intent) }.isSuccess
    }

    // MARK: - Scheduling

    /** Schedule (or reschedule) the alarm chain for a commitment. */
    fun schedule(commitment: Commitment) {
        cancel(commitment.id)
        if (!commitment.isEnabled) return

        val triggerAt = nextTriggerMillis(commitment)
        armAlarm(commitment, triggerAt, isNag = false)
        prefs.setNagCount(commitment.id, 0)
    }

    /**
     * Re-arm the next weekly occurrence right as the current one fires, without touching
     * the nag counter.
     *
     * AlarmKit keeps a recurring alarm alive by itself; AlarmManager fires once and
     * forgets. iOS gets away with re-scheduling only on proof-or-exhausted-chain because
     * the OS still holds the pattern. Here, a user who simply ignores the alarm — never
     * taps anything — would never re-arm it, and the commitment would silently stop
     * existing after one day. That is the worst possible bug for this app, so recurring
     * commitments re-arm the moment they ring.
     */
    fun rearmNextOccurrence(commitment: Commitment) {
        if (!commitment.isEnabled || !commitment.repeats.isRecurring) return
        armAlarm(
            commitment = commitment,
            triggerAtMillis = nextTriggerMillis(commitment),
            isNag = false,
        )
    }

    /**
     * Called when the user silenced the alarm but has not proved they started.
     * Returns false once we have run out of patience so the caller can stop promising
     * more — a nag chain with no end is a one-star review, and PRODUCT.md says so
     * explicitly.
     */
    fun scheduleNag(commitment: Commitment): Boolean {
        val count = prefs.nagCount(commitment.id)
        if (count >= MAX_NAGS) {
            prefs.clearNagCount(commitment.id)
            return false
        }

        armAlarm(
            commitment = commitment,
            triggerAtMillis = System.currentTimeMillis() + NAG_INTERVAL_MILLIS,
            isNag = true,
        )
        prefs.setNagCount(commitment.id, count + 1)
        return true
    }

    /** Proof accepted. Tear the chain down. */
    fun clearNags(commitmentId: UUID) {
        alarmManager.cancel(pendingIntentFor(commitmentId, isNag = true, mutate = false))
        prefs.clearNagCount(commitmentId)
    }

    fun cancel(commitmentId: UUID) {
        alarmManager.cancel(pendingIntentFor(commitmentId, isNag = false, mutate = false))
        clearNags(commitmentId)
    }

    private fun armAlarm(commitment: Commitment, triggerAtMillis: Long, isNag: Boolean) {
        val operation = pendingIntentFor(
            commitmentId = commitment.id,
            isNag = isNag,
            mutate = true,
            title = commitment.title,
        )

        // Tapping the status-bar alarm chip opens the app, not the ring screen.
        val showIntent = PendingIntent.getActivity(
            appContext,
            REQUEST_SHOW_INTENT,
            Intent(appContext, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        if (canScheduleExact()) {
            alarmManager.setAlarmClock(
                AlarmManager.AlarmClockInfo(triggerAtMillis, showIntent),
                operation,
            )
        } else {
            // Degraded mode: only reachable on API 31/32 with the permission revoked.
            // The alarm may drift by minutes in Doze. The UI surfaces a warning banner
            // rather than pretending this is fine, because a late alarm is a broken
            // promise and the user should know before they trust it with an exam.
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAtMillis,
                operation,
            )
        }
    }

    private fun pendingIntentFor(
        commitmentId: UUID,
        isNag: Boolean,
        mutate: Boolean,
        title: String? = null,
    ): PendingIntent {
        val intent = Intent(appContext, AlarmReceiver::class.java).apply {
            action = AlarmReceiver.ACTION_RING
            putExtra(AlarmReceiver.EXTRA_COMMITMENT_ID, commitmentId.toString())
            putExtra(AlarmReceiver.EXTRA_IS_NAG, isNag)
            title?.let { putExtra(AlarmReceiver.EXTRA_TITLE, it) }
        }

        // PendingIntent identity ignores extras, so the main alarm and the nag alarm must
        // differ by request code or the nag would silently replace the main schedule.
        val flags = PendingIntent.FLAG_IMMUTABLE or
            if (mutate) PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_NO_CREATE

        return PendingIntent.getBroadcast(
            appContext,
            requestCode(commitmentId, isNag),
            intent,
            flags,
        ) ?: PendingIntent.getBroadcast(
            // FLAG_NO_CREATE returned null (nothing scheduled) — build a throwaway so
            // callers of cancel() do not have to null-check. Cancelling a PendingIntent
            // that was never scheduled is a no-op.
            appContext,
            requestCode(commitmentId, isNag),
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    companion object {

        /** How long after a dismissed-without-proof ring we come back. */
        const val NAG_INTERVAL_MILLIS = 2 * 60 * 1000L

        /** Stop nagging eventually. Being unstoppable is a feature; being a bug report is not. */
        const val MAX_NAGS = 5

        private const val REQUEST_SHOW_INTENT = 1

        /**
         * Stable per-commitment request codes. `UUID.hashCode()` is a 32-bit fold of a
         * 128-bit value, so a collision between two commitments is theoretically possible;
         * with a realistic ceiling of a few dozen rows the odds are far below anything
         * else that can go wrong here.
         */
        private fun requestCode(commitmentId: UUID, isNag: Boolean): Int {
            val base = commitmentId.hashCode()
            return if (isNag) base * 31 + 1 else base
        }

        /**
         * Next wall-clock instant this commitment should fire.
         *
         * AlarmKit understands weekly recurrence natively; AlarmManager does not, so the
         * pattern is computed here and re-armed after every fire. Pure function, no
         * Android dependencies — the thing worth unit-testing in this file.
         */
        fun nextTriggerMillis(
            commitment: Commitment,
            after: Instant = Instant.now(),
            zone: ZoneId = ZoneId.systemDefault(),
        ): Long {
            val time = LocalTime.of(commitment.hour, commitment.minute)
            val today = after.atZone(zone).toLocalDate()

            if (!commitment.repeats.isRecurring) {
                // One-off. If the time has already passed today, roll to tomorrow rather
                // than scheduling in the past — AlarmManager would fire such an alarm
                // immediately, which reads as a bug to the user.
                val candidate = today.atTime(time).atZone(zone).toInstant()
                return if (candidate.isAfter(after)) candidate.toEpochMilli()
                else today.plusDays(1).atTime(time).atZone(zone).toInstant().toEpochMilli()
            }

            // Scan the next 8 days so "today, later" and "same weekday next week" are both
            // covered by the same loop.
            for (offset in 0L..7L) {
                val date = today.plusDays(offset)
                if (Weekdays.fromLocalDate(date) !in commitment.repeats.weekdays) continue
                val candidate = date.atTime(time).atZone(zone).toInstant()
                if (candidate.isAfter(after)) return candidate.toEpochMilli()
            }

            // Unreachable for a non-empty weekday set, but never return a past instant.
            return after.plusSeconds(60).toEpochMilli()
        }

        @Volatile
        private var instance: AlarmService? = null

        fun get(context: Context): AlarmService =
            instance ?: synchronized(this) {
                instance ?: AlarmService(context).also { instance = it }
            }
    }
}
