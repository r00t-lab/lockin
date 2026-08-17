package app.lockin.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import app.lockin.data.CommitmentStore

/**
 * Alarms do not survive a reboot — the OS drops every registered [android.app.AlarmManager]
 * entry — nor an app update. Both are silent failures: the user notices only when the
 * alarm they were relying on never rings.
 *
 * Not direct-boot aware on purpose. `commitments.json` lives in credential-encrypted
 * storage, which is unreadable until the user unlocks the device for the first time after
 * boot. `ACTION_BOOT_COMPLETED` is delivered after that unlock, so the file is readable by
 * the time this runs. Making it direct-boot aware would mean moving the data to
 * device-protected storage — more moving parts than the problem is worth.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            ACTION_QUICKBOOT_POWERON,
            -> Unit
            else -> return
        }

        val pending = goAsync()
        val appContext = context.applicationContext
        CoroutineScope(SupervisorJob() + Dispatchers.IO).launch {
            try {
                CommitmentStore.get(appContext).rescheduleAll()
            } finally {
                pending.finish()
            }
        }
    }

    private companion object {
        const val ACTION_QUICKBOOT_POWERON = "android.intent.action.QUICKBOOT_POWERON"
    }
}
