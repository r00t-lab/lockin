package app.lockin

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.lifecycleScope
import app.lockin.alarm.AlarmNotifications
import app.lockin.alarm.AlarmService
import app.lockin.billing.SubscriptionService
import app.lockin.data.CommitmentStore
import app.lockin.data.LockinPreferences
import app.lockin.model.Commitment
import app.lockin.system.SystemPrompts
import app.lockin.ui.AlarmWarning
import app.lockin.ui.CommitmentListScreen
import app.lockin.ui.DeskCodeScreen
import app.lockin.ui.WeeklyReportScreen
import app.lockin.ui.NewCommitmentSheet
import app.lockin.ui.OnboardingScreen
import app.lockin.ui.PaywallScreen
import app.lockin.ui.ProofScreen
import app.lockin.ui.theme.LockinTheme
import kotlinx.coroutines.launch
import java.util.UUID

class MainActivity : ComponentActivity() {

    private lateinit var store: CommitmentStore
    private lateinit var prefs: LockinPreferences
    private lateinit var alarms: AlarmService
    private val subscriptions = SubscriptionService.get()

    /**
     * Bumped whenever the activity comes forward, so the Compose tree re-checks for a
     * commitment parked by the alarm's "I'm starting" button. The equivalent of iOS's
     * `onChange(of: scenePhase)`.
     */
    private var resumeTick by mutableStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        store = CommitmentStore.get(this)
        prefs = LockinPreferences.get(this)
        alarms = AlarmService.get(this)

        lifecycleScope.launch { subscriptions.refresh() }

        setContent {
            LockinTheme {
                LockinApp(
                    store = store,
                    prefs = prefs,
                    alarms = alarms,
                    subscriptions = subscriptions,
                    resumeTick = resumeTick,
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        resumeTick++
    }

    override fun onResume() {
        super.onResume()
        resumeTick++
    }
}

private sealed interface Screen {
    data object List : Screen
    data object New : Screen
    data object Paywall : Screen
    data class Proof(val commitmentId: UUID) : Screen
    data class DeskCode(val commitmentId: UUID) : Screen
    data object Report : Screen
}

@Composable
private fun LockinApp(
    store: CommitmentStore,
    prefs: LockinPreferences,
    alarms: AlarmService,
    subscriptions: SubscriptionService,
    resumeTick: Int,
) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val commitments by store.commitments.collectAsStateWithLifecycle()
    val isPro by subscriptions.isPro.collectAsStateWithLifecycle()

    var hasOnboarded by remember { mutableStateOf(prefs.hasOnboarded) }
    var screen by remember { mutableStateOf<Screen>(Screen.List) }

    // Recomputed on every foregrounding so a permission granted in Settings clears its
    // banner without needing a restart.
    var warningEpoch by remember { mutableStateOf(0) }

    val notificationPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { warningEpoch++ }

    /**
     * The intent parked a commitment id before foregrounding us. Pick it up and go
     * straight to proof — never make the user find the row themselves at 7am.
     */
    LaunchedEffect(resumeTick) {
        warningEpoch++
        store.reconcileRehearsal()
        prefs.takePendingProof()?.let { id ->
            if (store.commitment(id) != null) screen = Screen.Proof(id)
        }
    }

    if (!hasOnboarded) {
        OnboardingScreen(
            onFinished = {
                prefs.hasOnboarded = true
                hasOnboarded = true
                screen = Screen.New
            },
        )
        return
    }

    when (val current = screen) {
        Screen.List -> {
            val stats = remember(commitments) { store.stats() }
            val warnings = remember(commitments, warningEpoch) {
                buildWarnings(
                    context = context,
                    alarms = alarms,
                    hasCommitments = commitments.isNotEmpty(),
                    onRequestNotifications = {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                        }
                    },
                )
            }

            CommitmentListScreen(
                commitments = commitments,
                stats = stats,
                warnings = warnings,
                onAdd = {
                    screen = if (store.canAddAnother(isPro)) Screen.New else Screen.Paywall
                },
                onDelete = { commitment -> scope.launch { store.delete(commitment) } },
                onOpenProof = { commitment -> screen = Screen.Proof(commitment.id) },
                onOpenDeskCode = { commitment -> screen = Screen.DeskCode(commitment.id) },
                onOpenReport = { screen = Screen.Report },
                onRehearse = {
                    scope.launch {
                        // The timer rehearsal is the one that finishes without asking for
                        // the camera, so it is the one that works the first time on a
                        // phone that has not granted anything yet.
                        store.startRehearsal(Commitment.ProofKind.FOCUS_TIMER)
                    }
                },
            )
        }

        Screen.New -> NewCommitmentSheet(
            onCancel = { screen = Screen.List },
            onSave = { commitment ->
                scope.launch {
                    store.add(commitment)
                    screen = if (commitment.proofKind == Commitment.ProofKind.DESK_CODE) {
                        Screen.DeskCode(commitment.id)
                    } else {
                        Screen.List
                    }

                    // Permissions are asked for here — after the user has committed to
                    // something — and never on launch.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                        ContextCompat.checkSelfPermission(
                            context,
                            Manifest.permission.POST_NOTIFICATIONS,
                        ) != PackageManager.PERMISSION_GRANTED
                    ) {
                        notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS)
                    }

                    if (!prefs.hasAskedBatteryExemption) {
                        prefs.hasAskedBatteryExemption = true
                        SystemPrompts.requestBatteryExemption(context)
                    }

                    alarms.requestExactAlarmPermission()
                    warningEpoch++
                }
            },
        )

        Screen.Paywall -> PaywallScreen(
            subscriptions = subscriptions,
            onDismiss = { screen = Screen.List },
        )

        Screen.Report -> WeeklyReportScreen(
            commitments = commitments,
            onFinish = { screen = Screen.List },
        )

        is Screen.DeskCode -> {
            val commitment: Commitment? = commitments.firstOrNull { it.id == current.commitmentId }
            if (commitment == null) {
                LaunchedEffect(current) { screen = Screen.List }
            } else {
                DeskCodeScreen(commitment = commitment, onFinish = { screen = Screen.List })
            }
        }

        is Screen.Proof -> {
            val commitment: Commitment? = commitments.firstOrNull { it.id == current.commitmentId }
            if (commitment == null) {
                LaunchedEffect(current) { screen = Screen.List }
            } else {
                ProofScreen(
                    commitment = commitment,
                    // Returns the streak the proof just earned, so the payoff screen has a
                    // number to show. A rehearsal drops its own row on proof, so there is
                    // nothing to read back and the screen says "done" instead of a count —
                    // which is correct: a rehearsal earns no streak.
                    onProve = {
                        store.recordProof(commitment.id)
                        store.commitment(commitment.id)?.currentStreak ?: 0
                    },
                    onBailed = {
                        scope.launch {
                            store.recordDismissal(commitment.id)
                            screen = Screen.List
                        }
                    },
                    onFinish = { screen = Screen.List },
                )
            }
        }
    }
}

/**
 * Everything that can quietly break the alarm, surfaced in the list instead of a dialog.
 * An alarm app that does not ring is worse than no alarm app, so these are not subtle.
 */
private fun buildWarnings(
    context: android.content.Context,
    alarms: AlarmService,
    hasCommitments: Boolean,
    onRequestNotifications: () -> Unit,
): List<AlarmWarning> {
    if (!hasCommitments) return emptyList()
    val warnings = mutableListOf<AlarmWarning>()

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS,
        ) != PackageManager.PERMISSION_GRANTED
    ) {
        warnings += AlarmWarning(
            id = "notifications",
            message = "Notifications are off, so the alarm has nothing to appear in. " +
                "It will not ring.",
            actionLabel = "Turn them on",
            onAction = onRequestNotifications,
        )
    }

    if (!alarms.canScheduleExact()) {
        warnings += AlarmWarning(
            id = "exactAlarm",
            message = "Exact alarms are blocked. Lockin can only fire roughly on time, " +
                "which is not what you agreed to.",
            actionLabel = "Allow exact alarms",
            onAction = { alarms.requestExactAlarmPermission() },
        )
    }

    if (!AlarmNotifications.canUseFullScreenIntent(context)) {
        warnings += AlarmWarning(
            id = "fullScreen",
            message = "Lockin can't take over your screen, so the alarm will show as a " +
                "banner you can flick away.",
            actionLabel = "Allow full-screen alarms",
            onAction = { SystemPrompts.openFullScreenIntentSettings(context) },
        )
    }

    if (!SystemPrompts.isIgnoringBatteryOptimizations(context)) {
        warnings += AlarmWarning(
            id = "battery",
            message = "Battery optimisation can delay your alarm by minutes or skip it " +
                "on days you haven't opened the app.",
            actionLabel = "Exempt Lockin",
            onAction = { SystemPrompts.requestBatteryExemption(context) },
        )
    }

    return warnings
}
