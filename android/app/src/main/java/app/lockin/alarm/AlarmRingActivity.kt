package app.lockin.alarm

import android.app.KeyguardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.OnBackPressedCallback
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.lerp
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.lockin.ui.theme.EyebrowText
import app.lockin.ui.theme.LockinTheme
import app.lockin.ui.theme.MetaText
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.UUID

/**
 * The full-screen takeover. Launched by the notification's `fullScreenIntent`, never
 * directly — a background activity start would be blocked on Android 10+, and the
 * full-screen intent is the sanctioned path that also works over the lock screen.
 *
 * This screen owns no logic. Both buttons post an intent to [AlarmRingService] and let it
 * be the single place where "dismissed" and "starting" are defined, so the notification
 * actions and this UI can never drift apart.
 */
class AlarmRingActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreen()
        enableEdgeToEdge()

        val commitmentId = intent.getStringExtra(EXTRA_COMMITMENT_ID)
            ?.let { runCatching { UUID.fromString(it) }.getOrNull() }
        if (commitmentId == null) {
            finish()
            return
        }

        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty()
        val isNag = intent.getBooleanExtra(EXTRA_IS_NAG, false)
        val nagIndex = intent.getIntExtra(EXTRA_NAG_INDEX, 0)

        // Back is not an exit. It does not silence, it does not count as a dismissal —
        // the user has to say which one they mean. (Even if they force-quit, the service
        // keeps ringing; that is the point of the service.)
        onBackPressedDispatcher.addCallback(
            this,
            object : OnBackPressedCallback(true) {
                override fun handleOnBackPressed() = Unit
            },
        )

        setContent {
            LockinTheme {
                AlarmRingScreen(
                    title = title,
                    isNag = isNag,
                    nagIndex = nagIndex,
                    onStarting = {
                        startService(AlarmRingService.startProofIntent(this, commitmentId))
                        finish()
                    },
                    onDismiss = {
                        startService(AlarmRingService.dismissIntent(this, commitmentId))
                        finish()
                    },
                )
            }
        }
    }

    /**
     * The runtime half of the manifest's `showWhenLocked` / `turnScreenOn`. Both halves
     * are required: the manifest attributes cover API 27+, and `requestDismissKeyguard`
     * is what stops the user from having to unlock before they can even see what they
     * promised to do.
     */
    private fun showOverLockScreen() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            getSystemService(KeyguardManager::class.java)?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    companion object {
        private const val EXTRA_COMMITMENT_ID = "commitmentId"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_IS_NAG = "isNag"
        private const val EXTRA_NAG_INDEX = "nagIndex"

        fun intent(
            context: Context,
            commitmentId: UUID,
            isNag: Boolean,
            title: String,
            nagIndex: Int,
        ): Intent = Intent(context, AlarmRingActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            putExtra(EXTRA_COMMITMENT_ID, commitmentId.toString())
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_IS_NAG, isNag)
            putExtra(EXTRA_NAG_INDEX, nagIndex)
        }
    }
}

/** Hex-for-hex the prototype's `.alarm` overlay, including the 1.15s background pulse. */
@Composable
private fun AlarmRingScreen(
    title: String,
    isNag: Boolean,
    nagIndex: Int,
    onStarting: () -> Unit,
    onDismiss: () -> Unit,
) {
    val base = Color(0xFFC7351A)
    val deep = Color(0xFFA82912)
    val pale = Color(0xFFF6D9D2)
    val inkDeep = Color(0xFF4A1409)

    val transition = rememberInfiniteTransition(label = "alarmPulse")
    val pulse by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 575, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse,
        ),
        label = "alarmPulseFraction",
    )
    // animateColorAsState on a lerp keeps the pulse smooth without allocating per frame.
    val background by animateColorAsState(lerp(base, deep, pulse), label = "alarmBackground")

    val clock = remember {
        LocalTime.now().format(DateTimeFormatter.ofPattern("HH:mm", Locale.US))
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(background),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .systemBarsPadding()
                .padding(horizontal = 24.dp, vertical = 32.dp),
        ) {
            Text(
                text = if (isNag) "STILL HAVEN'T STARTED" else "YOU SAID YOU'D START",
                style = EyebrowText,
                color = pale,
            )
            Spacer(Modifier.height(14.dp))
            Text(
                text = title,
                fontSize = 36.sp,
                lineHeight = 40.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White,
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text = buildString {
                    append(clock)
                    if (isNag) append("   ·   $nagIndex of ${AlarmService.MAX_NAGS}")
                },
                style = MetaText,
                color = pale,
            )

            Spacer(Modifier.weight(1f))

            Button(
                onClick = onStarting,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(11.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.White,
                    contentColor = inkDeep,
                ),
                contentPadding = PaddingValues(vertical = 17.dp),
            ) {
                Text("I'm starting", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
            }

            Spacer(Modifier.height(10.dp))

            OutlinedButton(
                onClick = onDismiss,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(11.dp),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = pale),
                border = BorderStroke(1.dp, pale.copy(alpha = 0.42f)),
                contentPadding = PaddingValues(vertical = 15.dp),
            ) {
                Text(if (isNag) "Still not started" else "Dismiss", fontSize = 15.sp)
            }
        }
    }
}
