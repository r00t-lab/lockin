package app.lockin.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import app.lockin.data.CommitmentStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * Entry point for a fired alarm. Does as little as possible and hands off to
 * [AlarmRingService] — a receiver has roughly ten seconds before the system considers it
 * hung, and this one runs at the exact moment the user is least forgiving.
 */
class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_RING) return

        val rawId = intent.getStringExtra(EXTRA_COMMITMENT_ID) ?: return
        val commitmentId = runCatching { UUID.fromString(rawId) }.getOrNull() ?: return
        val isNag = intent.getBooleanExtra(EXTRA_IS_NAG, false)
        val fallbackTitle = intent.getStringExtra(EXTRA_TITLE).orEmpty()

        // Start ringing first, look things up second. The service reads the store itself
        // for the authoritative title; the extra is only a fallback for the case where
        // the row was edited between scheduling and firing.
        ContextCompat.startForegroundService(
            context,
            AlarmRingService.ringIntent(context, commitmentId, isNag, fallbackTitle),
        )

        // Then, off the receiver's clock, put the next weekly occurrence back on the
        // schedule. See AlarmService.rearmNextOccurrence for why this cannot wait for the
        // user to interact.
        val pending = goAsync()
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                if (!isNag) {
                    val store = CommitmentStore.get(context)
                    store.commitment(commitmentId)?.let {
                        AlarmService.get(context).rearmNextOccurrence(it)
                    }
                }
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        const val ACTION_RING = "app.lockin.action.RING"
        const val EXTRA_COMMITMENT_ID = "commitmentId"
        const val EXTRA_IS_NAG = "isNag"
        const val EXTRA_TITLE = "title"
    }
}
