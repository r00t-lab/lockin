package app.lockin.ui

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.PowerManager
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import app.lockin.alarm.AlarmService
import app.lockin.data.LockinPreferences
import app.lockin.model.Commitment
import app.lockin.ui.theme.EyebrowText
import app.lockin.ui.theme.Lockin
import app.lockin.ui.theme.MetaText

/**
 * What the app currently believes, on screen.
 *
 * ## Why this exists
 * Every round of debugging on this project has gone: something does not work on a device →
 * guess → a build → still broken. The devices are not ones a debugger can be attached to,
 * and asking someone to fish a log out of a phone while an alarm is going off has never
 * worked once. On Android it is about to be worse, not better: a dozen testers, a dozen
 * manufacturers, and each one with its own opinion about killing background work.
 *
 * So the app answers the questions itself. Every line here is one somebody would otherwise
 * have to guess at: is the alarm allowed to be exact, are notifications on at all, is the
 * app exempt from battery optimisation — the single most common reason an Android alarm
 * silently never fires — how many alarms are actually in each chain, and is there a proof
 * hand-off stuck in preferences.
 *
 * Reached by long-pressing the wordmark. No button, because this is not a feature and
 * nobody should find it by accident. It ships in release builds on purpose: the devices
 * that matter are the testers', and a diagnostic that only exists in a debug build is a
 * diagnostic that exists nowhere.
 */
@Composable
fun DiagnosticsScreen(
    commitments: List<Commitment>,
    onClose: () -> Unit,
) {
    val palette = Lockin.palette
    val context = LocalContext.current
    val alarms = AlarmService.get(context)
    val prefs = LockinPreferences.get(context)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.ground)
            .systemBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 26.dp),
    ) {
        Text("WHAT THE APP THINKS", style = EyebrowText, color = palette.ink3)
        Spacer(Modifier.height(10.dp))
        Text(
            "Read this out and the guessing stops.",
            fontSize = 20.sp,
            fontWeight = FontWeight.Medium,
            color = palette.ink,
        )
        Spacer(Modifier.height(22.dp))

        Section("Permissions") {
            DiagnosticRow("Exact alarms", if (alarms.canScheduleExact()) "allowed" else "BLOCKED")
            DiagnosticRow("Notifications", context.notificationStatus())
            DiagnosticRow("Camera", context.cameraStatus())
            // The one that silently breaks everything and never surfaces as an error.
            DiagnosticRow("Battery exemption", context.batteryExemptionStatus())
        }

        Section("Hand-off") {
            DiagnosticRow("Pending proof id", prefs.peekPendingProof()?.toString() ?: "none")
        }

        Section("Commitments (${commitments.size})") {
            if (commitments.isEmpty()) {
                DiagnosticRow("—", "none yet")
            } else {
                commitments.forEach { commitment ->
                    Spacer(Modifier.height(6.dp))
                    Text(
                        commitment.title,
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Medium,
                        color = palette.ink,
                    )
                    // 6 is a healthy chain: the ring plus five nags. 1 means the chain was
                    // never built, and that number appears on no other screen.
                    DiagnosticRow("  nags used", "${prefs.nagCount(commitment.id)} of ${AlarmService.MAX_NAGS}")
                    DiagnosticRow("  proof kind", commitment.proofKind.shortLabel)
                    DiagnosticRow("  streak / best", "${commitment.currentStreak} / ${commitment.bestStreak}")
                    DiagnosticRow("  excuses", commitment.missCount.toString())
                    if (commitment.isRehearsal) DiagnosticRow("  rehearsal", "yes")
                }
            }
        }

        Section("Build") {
            DiagnosticRow("Android", "API ${Build.VERSION.SDK_INT}")
            DiagnosticRow("Device", "${Build.MANUFACTURER} ${Build.MODEL}")
        }

        Spacer(Modifier.height(24.dp))
        TextButton(onClick = onClose, modifier = Modifier.fillMaxWidth()) {
            Text("Close", fontSize = 15.sp, color = palette.ink2)
        }
    }
}

@Composable
private fun Section(title: String, content: @Composable () -> Unit) {
    val palette = Lockin.palette
    Column(Modifier.padding(bottom = 20.dp)) {
        Text(title.uppercase(), style = EyebrowText, color = palette.ink3)
        Spacer(Modifier.height(8.dp))
        Column(verticalArrangement = Arrangement.spacedBy(4.dp)) { content() }
    }
}

@Composable
private fun DiagnosticRow(label: String, value: String) {
    val palette = Lockin.palette
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(label, style = MetaText.copy(fontSize = 12.sp), color = palette.ink2)
        Text(value, style = MetaText.copy(fontSize = 12.sp), color = palette.ink)
    }
}

private fun Context.notificationStatus(): String =
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
        "granted (pre-13)"
    } else if (
        ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
        == PackageManager.PERMISSION_GRANTED
    ) {
        "granted"
    } else {
        "DENIED"
    }

private fun Context.cameraStatus(): String =
    if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
        == PackageManager.PERMISSION_GRANTED
    ) {
        "granted"
    } else {
        "not granted"
    }

/**
 * Doze and app-standby are the reason an Android alarm app that works on the developer's
 * phone fails on somebody else's. `setAlarmClock` is exempt by design, so this is not
 * fatal — but when a tester reports a missed ring on a phone with an aggressive OEM
 * battery manager, this is the first line worth reading.
 */
private fun Context.batteryExemptionStatus(): String {
    val power = getSystemService(PowerManager::class.java) ?: return "unknown"
    return if (power.isIgnoringBatteryOptimizations(packageName)) "exempt" else "not exempt"
}
