package app.lockin.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import app.lockin.R
import java.util.UUID

/**
 * The notification half of the alarm. Everything here exists to satisfy the one
 * requirement in PRODUCT.md: the alarm has to take over the screen, and it has to get
 * through Do Not Disturb.
 */
object AlarmNotifications {

    const val CHANNEL_ALARM = "lockin.alarm"
    const val RING_NOTIFICATION_ID = 1001

    fun createChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val channel = NotificationChannel(
            CHANNEL_ALARM,
            "Commitment alarms",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "The alarm that makes you start what you said you'd start."
            // No channel sound: AlarmRingService drives a looping MediaPlayer on
            // USAGE_ALARM instead. A channel sound plays once and cannot be stopped
            // independently of the notification, which is useless for an alarm.
            setSound(null, null)
            enableVibration(false)
            // Only takes effect once the user grants notification-policy access, which
            // we never ask for. Harmless when ungranted, and USAGE_ALARM audio already
            // bypasses DND under the default "allow alarms" policy — which is the part
            // that actually carries the promise.
            setBypassDnd(true)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setShowBadge(false)
        }

        context.getSystemService(NotificationManager::class.java)
            .createNotificationChannel(channel)
    }

    /**
     * Whether the OS will actually honour [NotificationCompat.Builder.setFullScreenIntent].
     * Android 14 revoked the free-for-all; alarm apps are supposed to keep it, but a
     * denial here silently downgrades the product to a heads-up banner, so the UI checks
     * and offers the settings deep link.
     */
    fun canUseFullScreenIntent(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return true
        return context.getSystemService(NotificationManager::class.java).canUseFullScreenIntent()
    }

    fun buildRingNotification(
        context: Context,
        commitmentId: UUID,
        title: String,
        isNag: Boolean,
        nagIndex: Int,
    ): Notification {

        val fullScreen = PendingIntent.getActivity(
            context,
            REQUEST_FULL_SCREEN,
            AlarmRingActivity.intent(context, commitmentId, isNag, title, nagIndex),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val eyebrow = if (isNag) "Still haven't started" else "You said you'd start"

        return NotificationCompat.Builder(context, CHANNEL_ALARM)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title.ifBlank { "Time to start" })
            .setContentText(eyebrow)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            // Ongoing + no auto-cancel: a swipe must not be a way out of the mechanic.
            .setOngoing(true)
            .setAutoCancel(false)
            // `true` = show the full-screen UI even when the screen is already on. That
            // is the whole point; without the flag it degrades to a heads-up banner the
            // user can flick away without reading.
            .setFullScreenIntent(fullScreen, true)
            .setContentIntent(fullScreen)
            .addAction(
                0,
                "I'm starting",
                servicePendingIntent(
                    context,
                    REQUEST_ACTION_PROOF,
                    AlarmRingService.startProofIntent(context, commitmentId),
                ),
            )
            .addAction(
                0,
                if (isNag) "Still not started" else "Dismiss",
                servicePendingIntent(
                    context,
                    REQUEST_ACTION_DISMISS,
                    AlarmRingService.dismissIntent(context, commitmentId),
                ),
            )
            .build()
    }

    private fun servicePendingIntent(context: Context, requestCode: Int, intent: Intent) =
        PendingIntent.getService(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    private const val REQUEST_FULL_SCREEN = 10
    private const val REQUEST_ACTION_PROOF = 11
    private const val REQUEST_ACTION_DISMISS = 12
}
