package app.lockin.proof

import android.annotation.SuppressLint
import android.content.Context
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
// ⚠️ This moved: it used to be androidx.compose.ui.platform.LocalLifecycleOwner, which is
// now deprecated in favour of the lifecycle-compose one. If your Compose BOM predates the
// move, swap the import back.
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * QR scanner for the desk-sticker proof mode.
 *
 * The sticker is just the commitment's UUID rendered as a QR code — see [DeskCode]. Cheap
 * to build, and physically getting to the desk is the entire point of the hardest proof
 * mode.
 *
 * ⚠️ SIGNATURE NOTE: this is written against ML Kit's `barcode-scanning` 17.x surface
 * (`BarcodeScanning.getClient`, `InputImage.fromMediaImage`, `Barcode.rawValue`) and
 * CameraX 1.4's (`ProcessCameraProvider.getInstance`, `ImageAnalysis.Builder`). Both have
 * been stable for years, but neither could be compiled here. If the build fails it will
 * be in [bindCamera] and nowhere else.
 */
@Composable
fun QrScannerView(
    modifier: Modifier = Modifier,
    onScan: (String) -> Unit,
) {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val currentOnScan by rememberUpdatedState(onScan)

    // One scan per presentation. Without this the analyser fires every frame and the
    // proof gets recorded dozens of times — the same guard as the iOS ScannerViewController.
    val hasScanned = remember { AtomicBoolean(false) }
    val executor = remember { Executors.newSingleThreadExecutor() }
    val previewView = remember { PreviewView(context) }

    DisposableEffect(Unit) {
        val providerFuture = ProcessCameraProvider.getInstance(context)
        providerFuture.addListener(
            {
                runCatching {
                    bindCamera(
                        context = context,
                        provider = providerFuture.get(),
                        lifecycleOwner = lifecycleOwner,
                        previewView = previewView,
                        executor = executor,
                    ) { value ->
                        if (hasScanned.compareAndSet(false, true)) currentOnScan(value)
                    }
                }
            },
            ContextCompat.getMainExecutor(context),
        )

        onDispose {
            runCatching { ProcessCameraProvider.getInstance(context).get().unbindAll() }
            executor.shutdown()
        }
    }

    AndroidView(factory = { previewView }, modifier = modifier)
}

@SuppressLint("UnsafeOptInUsageError")
private fun bindCamera(
    context: Context,
    provider: ProcessCameraProvider,
    lifecycleOwner: androidx.lifecycle.LifecycleOwner,
    previewView: PreviewView,
    executor: java.util.concurrent.Executor,
    onValue: (String) -> Unit,
) {
    val scanner = BarcodeScanning.getClient(
        BarcodeScannerOptions.Builder()
            .setBarcodeFormats(Barcode.FORMAT_QR_CODE)
            .build(),
    )

    val preview = Preview.Builder().build().also {
        // Explicit setter, not the synthesised Kotlin property: `getSurfaceProvider()`
        // did not exist on Preview until recently, and property syntax silently fails to
        // resolve without it.
        it.setSurfaceProvider(previewView.surfaceProvider)
    }

    val analysis = ImageAnalysis.Builder()
        // Drop frames rather than queue them: a two-second-old frame is worthless and
        // the backlog is what makes cheap phones feel like the scanner has frozen.
        .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
        .build()

    analysis.setAnalyzer(executor) { imageProxy ->
        val mediaImage = imageProxy.image
        if (mediaImage == null) {
            imageProxy.close()
            return@setAnalyzer
        }

        val input = InputImage.fromMediaImage(mediaImage, imageProxy.imageInfo.rotationDegrees)
        scanner.process(input)
            .addOnSuccessListener { barcodes ->
                barcodes.firstNotNullOfOrNull { it.rawValue }?.let(onValue)
            }
            .addOnCompleteListener { imageProxy.close() }
    }

    provider.unbindAll()
    provider.bindToLifecycle(
        lifecycleOwner,
        CameraSelector.DEFAULT_BACK_CAMERA,
        preview,
        analysis,
    )
}
