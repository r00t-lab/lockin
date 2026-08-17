package app.lockin.system

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings

/**
 * The three OS-level settings that decide whether this app works at all, and the intents
 * that take the user to each.
 *
 * All of them are asked for *after* the first commitment exists, never on launch. A cold
 * permission prompt on launch is the single biggest conversion leak in this category —
 * the user has to want the alarm before they are asked to allow it. Same rule as iOS.
 */
object SystemPrompts {

    // MARK: - Battery optimisation

    fun isIgnoringBatteryOptimizations(context: Context): Boolean {
        val power = context.getSystemService(PowerManager::class.java) ?: return true
        return power.isIgnoringBatteryOptimizations(context.packageName)
    }

    /**
     * Aggressive OEM battery managers (Xiaomi, Oppo, Samsung's adaptive battery) will
     * happily defer a `setAlarmClock` alarm on a "not recently used" app. The exemption is
     * what stops a commitment set on Monday from silently failing on Friday.
     *
     * Prefers the direct request dialog. That needs `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`,
     * which is Play-restricted — allowed for alarm clocks, but if you would rather not
     * carry the declaration, drop the permission from the manifest and this falls through
     * to the settings list on its own.
     */
    fun requestBatteryExemption(context: Context) {
        if (isIgnoringBatteryOptimizations(context)) return

        val direct = Intent(
            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
            Uri.parse("package:${context.packageName}"),
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        if (runCatching { context.startActivity(direct) }.isSuccess) return

        runCatching {
            context.startActivity(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    // MARK: - Full-screen intent (Android 14+)

    /**
     * Android 14 made full-screen intents opt-in for most apps. Alarm clocks are supposed
     * to keep the grant by default, but "supposed to" is doing a lot of work on OEM
     * builds, so check and offer the deep link rather than assume.
     */
    fun openFullScreenIntentSettings(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) return
        runCatching {
            context.startActivity(
                Intent(
                    Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }

    // MARK: - App settings (notification permission permanently denied)

    fun openAppSettings(context: Context) {
        runCatching {
            context.startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
        }
    }
}
