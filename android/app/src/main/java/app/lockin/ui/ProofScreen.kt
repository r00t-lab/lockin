package app.lockin.ui

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import app.lockin.model.Commitment
import app.lockin.proof.DeskPhotoValidator
import app.lockin.proof.QrScannerView
import app.lockin.ui.theme.CountdownNumber
import app.lockin.ui.theme.EyebrowText
import app.lockin.ui.theme.Lockin
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.util.Locale

/**
 * The moment the whole product exists for: the user has to demonstrate they started.
 *
 * Design rule — this screen must be finishable in under 8 seconds. Every extra tap is a
 * person going back to bed. No settings, no explanations, one action.
 */
@Composable
fun ProofScreen(
    commitment: Commitment,
    onProve: suspend () -> Int,
    onBailed: () -> Unit,
    onFinish: () -> Unit,
) {
    val palette = Lockin.palette
    val scope = rememberCoroutineScope()
    var rejection by remember { mutableStateOf<String?>(null) }

    // Set once proof has landed and the user is done watching whatever they were watching.
    var provenStreak by remember { mutableStateOf<Int?>(null) }
    // Earned at the moment the timer starts, shown when they say they are finished.
    var heldStreak by remember { mutableStateOf<Int?>(null) }
    var timerRunning by remember { mutableStateOf(false) }

    provenStreak?.let { streak ->
        ProofAccepted(streak = streak, onFinish = onFinish)
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.ground)
            .systemBarsPadding()
            .padding(horizontal = 20.dp, vertical = 24.dp),
    ) {
        Text(
            text = "YOU SAID YOU'D START",
            style = EyebrowText,
            color = palette.ink3,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            text = commitment.title,
            fontSize = 28.sp,
            lineHeight = 34.sp,
            fontWeight = FontWeight.Bold,
            color = palette.ink,
        )
        if (commitment.currentStreak > 0) {
            Spacer(Modifier.height(6.dp))
            Text(
                text = "${commitment.currentStreak} day streak on the line",
                fontSize = 14.sp,
                color = palette.alarm,
            )
        }

        Box(Modifier.weight(1f)) {
            when (commitment.proofKind) {
                Commitment.ProofKind.PHOTO -> PhotoProof(
                    onRejected = { rejection = it },
                    onAccepted = { scope.launch { provenStreak = onProve() } },
                )

                Commitment.ProofKind.FOCUS_TIMER -> TimerProof(
                    running = timerRunning,
                    onStarted = {
                        timerRunning = true
                        scope.launch { heldStreak = onProve() }
                    },
                    onDone = { provenStreak = heldStreak ?: 0 },
                )

                Commitment.ProofKind.DESK_CODE -> DeskCodeProof(
                    expectedPayload = commitment.id.toString(),
                    onRejected = { rejection = it },
                    onAccepted = { scope.launch { provenStreak = onProve() } },
                )
            }
        }

        rejection?.let {
            Text(
                text = it,
                fontSize = 13.sp,
                color = palette.alarm,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 12.dp),
            )
        }

        // Gone once the timer is running. Proof has already landed by then, and a button
        // that records an excuse against a day the user showed up is worse than no button:
        // it is the app calling them a liar for staying on the screen.
        if (!timerRunning) {
            TextButton(
                onClick = onBailed,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text("I'm not doing it", fontSize = 13.sp, color = palette.ink3)
            }
        }
    }
}

/**
 * The payoff.
 *
 * Not decoration. CONTENT.md lists "a celebration beat at the end" as one of the five
 * things every video in this category has in common, and without it proof lands and the
 * screen simply closes — a video with no last second. It is also the only moment Nagg ever
 * gives anything back, in an app whose entire job is to be unpleasant at 7am.
 *
 * It dismisses itself. A tap-to-continue would put a decision in front of someone who has
 * just earned the opposite.
 */
@Composable
private fun ProofAccepted(streak: Int, onFinish: () -> Unit) {
    val palette = Lockin.palette

    LaunchedEffect(Unit) {
        // Long enough to read and to film, short enough that nobody has to dismiss it.
        delay(1900)
        onFinish()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.ground)
            .systemBarsPadding()
            .padding(horizontal = 40.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = if (streak > 0) streak.toString() else "done",
            style = CountdownNumber.copy(fontSize = 96.sp),
            color = palette.go,
        )
        Spacer(Modifier.height(14.dp))
        Text(
            text = payoffLine(streak),
            fontSize = 16.sp,
            lineHeight = 23.sp,
            color = palette.ink2,
            textAlign = TextAlign.Center,
        )
    }
}

/** The copy does the work the number cannot. Day one has nothing to boast about yet. */
private fun payoffLine(streak: Int): String = when (streak) {
    0 -> "Started. That was the whole point."
    1 -> "Day one. The alarm has nothing on you."
    in 2..6 -> "$streak days straight."
    else -> "$streak days. Nagg has stopped arguing with you."
}

// MARK: - Photo

/**
 * System camera, no custom capture UI. The proof screen is time-critical; a bespoke
 * CameraX capture pipeline is exactly the kind of work that feels productive and ships
 * nothing. Same call as iOS.
 *
 * Note the CAMERA permission is required here even though `ACTION_IMAGE_CAPTURE` normally
 * needs none: once an app *declares* CAMERA in its manifest — which this one must, for
 * the QR scanner — the system starts enforcing it for the capture intent too. That
 * interaction is a classic silent-crash source.
 */
@Composable
private fun PhotoProof(
    onRejected: (String) -> Unit,
    onAccepted: () -> Unit,
) {
    val palette = Lockin.palette
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    var preview by remember { mutableStateOf<Bitmap?>(null) }
    var isChecking by remember { mutableStateOf(false) }
    var captureUri by remember { mutableStateOf<Uri?>(null) }

    val takePicture = rememberLauncherForActivityResult(
        ActivityResultContracts.TakePicture(),
    ) { success ->
        val uri = captureUri
        if (!success || uri == null) return@rememberLauncherForActivityResult

        isChecking = true
        scope.launch {
            val bitmap = withContext(Dispatchers.IO) { loadBitmap(context, uri) }
            if (bitmap == null) {
                isChecking = false
                onRejected("Couldn't read that photo. Try again.")
                return@launch
            }
            preview = bitmap

            val result = withContext(Dispatchers.Default) { DeskPhotoValidator.validate(bitmap) }
            isChecking = false

            when (result) {
                is DeskPhotoValidator.Result.Accepted -> onAccepted()
                is DeskPhotoValidator.Result.Rejected -> {
                    preview = null
                    onRejected(result.message)
                }
            }
            withContext(Dispatchers.IO) { runCatching { context.captureFile().delete() } }
        }
    }

    val cameraPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (granted) {
            captureUri = context.newCaptureUri()
            captureUri?.let(takePicture::launch)
        } else {
            onRejected("Nagg needs the camera to check you're actually at your desk.")
        }
    }

    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(190.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(palette.sunk),
            contentAlignment = Alignment.Center,
        ) {
            val shot = preview
            if (shot != null) {
                Image(
                    bitmap = shot.asImageBitmap(),
                    contentDescription = null,
                    contentScale = ContentScale.Crop,
                    modifier = Modifier.fillMaxSize(),
                )
            } else {
                Text(
                    "point it at your desk or your open laptop",
                    fontSize = 13.sp,
                    color = palette.ink3,
                    textAlign = TextAlign.Center,
                )
            }
        }

        Spacer(Modifier.height(16.dp))

        Button(
            onClick = {
                if (context.hasCameraPermission()) {
                    captureUri = context.newCaptureUri()
                    captureUri?.let(takePicture::launch)
                } else {
                    cameraPermission.launch(Manifest.permission.CAMERA)
                }
            },
            enabled = !isChecking,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(11.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = palette.ink,
                contentColor = palette.ground,
            ),
            contentPadding = PaddingValues(vertical = 15.dp),
        ) {
            Text(
                if (preview == null) "Photograph your setup" else "Retake",
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
            )
        }

        if (isChecking) {
            Spacer(Modifier.height(16.dp))
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = palette.ink3)
            }
        }
    }
}

// MARK: - Focus timer

@Composable
private fun TimerProof(
    running: Boolean,
    onStarted: () -> Unit,
    onDone: () -> Unit,
) {
    val palette = Lockin.palette
    var remaining by remember { mutableStateOf(25 * 60) }

    LaunchedEffect(running) {
        if (!running) return@LaunchedEffect
        while (remaining > 0) {
            delay(1000)
            remaining -= 1
        }
        // Sat through the whole thing without being asked to. That earns the beat.
        onDone()
    }

    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = String.format(Locale.US, "%02d:%02d", remaining / 60, remaining % 60),
            style = CountdownNumber,
            color = if (running) palette.go else palette.ink,
        )
        Spacer(Modifier.height(24.dp))
        Button(
            onClick = {
                // Starting is the proof. Finishing is between them and their degree.
                onStarted()
            },
            enabled = !running,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(11.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = palette.ink,
                contentColor = palette.ground,
            ),
            contentPadding = PaddingValues(vertical = 15.dp),
        ) {
            Text(
                if (running) "Running" else "Start 25 minutes",
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
            )
        }

        // The clock is the only part of this proof the user can watch, and the payoff
        // screen used to take over on the same tap and destroy it before a second ticked.
        // So the payoff waits: until the timer runs out, or until they say they are done.
        if (running) {
            Spacer(Modifier.height(20.dp))
            Text(
                "The alarm is off. The next 25 minutes are yours.",
                fontSize = 14.sp,
                lineHeight = 21.sp,
                color = palette.ink2,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(horizontal = 24.dp),
            )
            Spacer(Modifier.height(12.dp))
            TextButton(onClick = onDone, modifier = Modifier.fillMaxWidth()) {
                Text("Done", fontSize = 15.sp, color = palette.ink2)
            }
        }
    }
}

// MARK: - Desk code

@Composable
private fun DeskCodeProof(
    expectedPayload: String,
    onRejected: (String) -> Unit,
    onAccepted: () -> Unit,
) {
    val palette = Lockin.palette
    val context = LocalContext.current
    var granted by remember { mutableStateOf(context.hasCameraPermission()) }

    val cameraPermission = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { result ->
        granted = result
        if (!result) onRejected("Nagg needs the camera to read your desk code.")
    }

    LaunchedEffect(Unit) {
        if (!granted) cameraPermission.launch(Manifest.permission.CAMERA)
    }

    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            "Scan the sticker on your desk",
            fontSize = 16.sp,
            fontWeight = FontWeight.Medium,
            color = palette.ink,
            modifier = Modifier.fillMaxWidth(),
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(16.dp))
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(300.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(palette.sunk),
            contentAlignment = Alignment.Center,
        ) {
            if (granted) {
                QrScannerView(
                    modifier = Modifier.fillMaxSize(),
                    onScan = { payload ->
                        if (payload == expectedPayload) onAccepted()
                        else onRejected("Wrong code. That's not your desk.")
                    },
                )
            } else {
                Text("Camera access needed", fontSize = 13.sp, color = palette.ink3)
            }
        }
    }
}

// MARK: - Capture plumbing

private const val CAPTURE_FILENAME = "proof-capture.jpg"

private fun Context.captureFile(): File = File(cacheDir, CAPTURE_FILENAME)

/**
 * Cache directory only, and deleted immediately after validation. The photo is evidence
 * for one decision that happens on this device; keeping it would turn a zero-disclosure
 * app into one with a data-retention story to tell.
 */
private fun Context.newCaptureUri(): Uri? = runCatching {
    val file = captureFile().apply {
        parentFile?.mkdirs()
        if (exists()) delete()
        createNewFile()
    }
    FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
}.getOrNull()

private fun Context.hasCameraPermission(): Boolean =
    ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA) ==
        PackageManager.PERMISSION_GRANTED

private fun loadBitmap(context: Context, uri: Uri): Bitmap? = runCatching {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
        val source = ImageDecoder.createSource(context.contentResolver, uri)
        ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
            // Software config: DeskPhotoValidator calls getPixels(), which throws on the
            // HARDWARE bitmaps ImageDecoder hands back by default.
            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
            decoder.isMutableRequired = false
        }
    } else {
        context.contentResolver.openInputStream(uri).use { BitmapFactory.decodeStream(it) }
    }
}.getOrNull()
