package app.lockin.alarm

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.ServiceCompat
import app.lockin.MainActivity
import app.lockin.data.CommitmentStore
import app.lockin.data.LockinPreferences
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import java.util.UUID

/**
 * Makes the noise, and keeps making it.
 *
 * A foreground service rather than letting [AlarmRingActivity] own the sound, because the
 * full-screen intent is only *guaranteed* to take over the screen when the device is
 * locked. If the phone is unlocked and in the user's hand — which for a 7pm "start your
 * essay" alarm is the common case — the system shows a heads-up notification instead and
 * no activity is created. Without this service that alarm would be silent, which is the
 * one failure mode the product cannot survive.
 *
 * ⚠️ Play declaration: this runs as `specialUse`. There is no `alarm` foreground-service
 * type, and `mediaPlayback` invites a policy argument about media-player UX. See
 * docs/ANDROID-SETUP.md for the wording to submit.
 */
class AlarmRingService : Service() {

    private val handler = Handler(Looper.getMainLooper())

    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null
    private var wakeLock: PowerManager.WakeLock? = null

    private var ringingId: UUID? = null
    private var autoSilence: Runnable? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_RING -> handleRing(intent)
            ACTION_START_PROOF -> handleStartProof(intent)
            ACTION_DISMISS -> handleDismiss(intent)
            else -> stopSelf()
        }
        // Do not resurrect with a null intent: a restarted ring with no commitment id is
        // an alarm the user cannot silence from the UI.
        return START_NOT_STICKY
    }

    private fun handleRing(intent: Intent) {
        val commitmentId = intent.commitmentId() ?: run { stopSelf(); return }
        val isNag = intent.getBooleanExtra(EXTRA_IS_NAG, false)

        val store = CommitmentStore.get(this)
        val commitment = store.commitment(commitmentId)
        val title = commitment?.title
            ?: intent.getStringExtra(EXTRA_TITLE).orEmpty()

        // A commitment deleted between scheduling and firing must not ring.
        if (commitment == null && title.isBlank()) {
            stopSelf()
            return
        }

        ringingId = commitmentId
        val nagIndex = LockinPreferences.get(this).nagCount(commitmentId)

        val notification = AlarmNotifications.buildRingNotification(
            context = this,
            commitmentId = commitmentId,
            title = title,
            isNag = isNag,
            nagIndex = nagIndex,
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            ServiceCompat.startForeground(
                this,
                AlarmNotifications.RING_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(AlarmNotifications.RING_NOTIFICATION_ID, notification)
        }

        acquireWakeLock()
        startSound()
        startVibration()
        scheduleAutoSilence(commitmentId)
    }

    /** "I'm starting" — park the id and bring the app up on the proof screen. */
    private fun handleStartProof(intent: Intent) {
        val commitmentId = intent.commitmentId() ?: ringingId ?: run { stopSelf(); return }
        val appContext = applicationContext
        LockinPreferences.get(this).setPendingProof(commitmentId)

        startActivity(
            Intent(this, MainActivity::class.java).addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP,
            ),
        )
        stopEverything()

        // No miss is recorded — the user has announced an intention, and punishing that
        // would train them to hit Dismiss instead. But a nag IS armed, because otherwise
        // "I'm starting" would be a free silence: tap it, close the app, never prove, and
        // the alarm never comes back. Only CommitmentStore.recordProof clears the chain.
        backgroundScope.launch {
            val store = CommitmentStore.get(appContext)
            store.commitment(commitmentId)?.let {
                AlarmService.get(appContext).scheduleNag(it)
            }
        }
    }

    /** "Dismiss" / "Still not started" — a miss, and the chain continues. */
    private fun handleDismiss(intent: Intent) {
        val commitmentId = intent.commitmentId() ?: ringingId
        stopEverything()
        commitmentId ?: return

        val store = CommitmentStore.get(applicationContext)
        backgroundScope.launch { store.recordDismissal(commitmentId) }
    }

    /**
     * The user walked away and never touched the phone. AlarmKit ends a ring by itself;
     * AlarmManager has no such notion, so an ignored alarm would ring until the battery
     * died. Treat silence as a dismissal so the nag chain still advances — and still
     * terminates at MAX_NAGS.
     */
    private fun scheduleAutoSilence(commitmentId: UUID) {
        autoSilence?.let(handler::removeCallbacks)
        val runnable = Runnable {
            val store = CommitmentStore.get(applicationContext)
            backgroundScope.launch { store.recordDismissal(commitmentId) }
            stopEverything()
        }
        autoSilence = runnable
        handler.postDelayed(runnable, AUTO_SILENCE_MILLIS)
    }

    // MARK: - Noise

    private fun startSound() {
        if (player != null) return

        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ?: return

        player = runCatching {
            MediaPlayer().apply {
                setDataSource(this@AlarmRingService, uri)
                // USAGE_ALARM is what makes this ring with the phone on silent and under
                // Do Not Disturb. It is the whole Android answer to AlarmKit.
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                isLooping = true
                setOnErrorListener { _, _, _ -> true }
                prepare()
                start()
            }
        }.getOrNull()

        // Deliberately not raising STREAM_ALARM volume. Overriding a level the user set
        // themselves is how alarm apps earn their one-star reviews, and PRODUCT.md's red
        // line is that the harshness comes from the nag chain, not from hostility.
    }

    private fun startVibration() {
        val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            getSystemService(VibratorManager::class.java)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Vibrator::class.java)
        } ?: return

        vibrator = vib
        val pattern = longArrayOf(0, 400, 200, 400, 1000)
        val attributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        runCatching {
            vib.vibrate(VibrationEffect.createWaveform(pattern, 0), attributes)
        }
    }

    private fun acquireWakeLock() {
        if (wakeLock != null) return
        val power = getSystemService(PowerManager::class.java) ?: return
        wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKE_LOCK_TAG).apply {
            setReferenceCounted(false)
            // Timeout slightly past auto-silence so a leaked lock cannot outlive the ring.
            acquire(AUTO_SILENCE_MILLIS + 10_000L)
        }
    }

    private fun stopEverything() {
        autoSilence?.let(handler::removeCallbacks)
        autoSilence = null

        runCatching { player?.stop() }
        runCatching { player?.release() }
        player = null

        runCatching { vibrator?.cancel() }
        vibrator = null

        runCatching { if (wakeLock?.isHeld == true) wakeLock?.release() }
        wakeLock = null

        ringingId = null
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        stopEverything()
        super.onDestroy()
    }

    private fun Intent.commitmentId(): UUID? =
        getStringExtra(EXTRA_COMMITMENT_ID)?.let { raw -> runCatching { UUID.fromString(raw) }.getOrNull() }

    companion object {

        /**
         * Process-scoped, deliberately never cancelled.
         *
         * Every write this service kicks off — recording a miss, arming the next nag —
         * happens as it is shutting itself down. Hanging those off a service-scoped job
         * means `onDestroy` cancels them mid-flight and the miss is lost, which is the
         * kind of bug that only shows up as "my streak is wrong sometimes". The work is
         * bounded (one small file write) so an uncancellable scope is the right trade.
         */
        private val backgroundScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

        const val ACTION_RING = "app.lockin.service.RING"
        const val ACTION_START_PROOF = "app.lockin.service.START_PROOF"
        const val ACTION_DISMISS = "app.lockin.service.DISMISS"

        const val EXTRA_COMMITMENT_ID = "commitmentId"
        const val EXTRA_IS_NAG = "isNag"
        const val EXTRA_TITLE = "title"

        /** How long an ignored alarm rings before it counts as a miss. */
        private const val AUTO_SILENCE_MILLIS = 2 * 60 * 1000L

        private const val WAKE_LOCK_TAG = "lockin:ring"

        fun ringIntent(
            context: Context,
            commitmentId: UUID,
            isNag: Boolean,
            title: String,
        ): Intent = Intent(context, AlarmRingService::class.java).apply {
            action = ACTION_RING
            putExtra(EXTRA_COMMITMENT_ID, commitmentId.toString())
            putExtra(EXTRA_IS_NAG, isNag)
            putExtra(EXTRA_TITLE, title)
        }

        fun startProofIntent(context: Context, commitmentId: UUID): Intent =
            Intent(context, AlarmRingService::class.java).apply {
                action = ACTION_START_PROOF
                putExtra(EXTRA_COMMITMENT_ID, commitmentId.toString())
            }

        fun dismissIntent(context: Context, commitmentId: UUID): Intent =
            Intent(context, AlarmRingService::class.java).apply {
                action = ACTION_DISMISS
                putExtra(EXTRA_COMMITMENT_ID, commitmentId.toString())
            }
    }
}
