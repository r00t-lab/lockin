package app.lockin.proof

import android.graphics.Bitmap
import androidx.core.graphics.scale
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Decides whether a photo plausibly shows a workspace. Runs entirely on the device and
 * makes no network call of any kind — see the note at the bottom for why that is a hard
 * constraint here and not just a preference.
 *
 * ## What it is actually checking
 * iOS uses `VNDetectRectanglesRequest`, which is really answering "is there structure in
 * this frame" — a desk has a screen, a keyboard, paper edges; a ceiling or the inside of
 * a pocket has none. There is no Vision framework here and ML Kit has no equivalent
 * general detector, so this reproduces the same signal directly from pixels:
 *
 *   1. **Too dark / too blown out** → the lens is covered or pointed at a lamp.
 *   2. **Flat luminance** → a blank wall, a ceiling, a duvet.
 *   3. **No edges** → nothing with a boundary is in frame.
 *
 * ## Calibration
 * PRODUCT.md is explicit: *a wrongly rejected photo is far worse than an accepted fake
 * one — the person cheating already paid.* Every threshold below is therefore set to
 * catch only the blatant cases. If you tune these, tune them looser. A user standing at
 * their desk at 7am who gets told "that isn't a desk" uninstalls immediately, and they
 * are right to.
 *
 * ⚠️ These constants are guesses on paper. Shoot ~20 real photos (desk, ceiling, pocket,
 * dark room, bed) on a device and print [analyse]'s output before trusting them; the
 * checklist in docs/ANDROID-SETUP.md has a step for exactly this.
 */
object DeskPhotoValidator {

    /** Longest edge we downscale to. 128px is plenty for gross structure and is instant. */
    private const val SAMPLE_SIZE = 128

    private const val MIN_MEAN_LUMA = 18.0
    private const val MAX_MEAN_LUMA = 245.0
    private const val MIN_LUMA_STD_DEV = 12.0
    private const val MIN_EDGE_RATIO = 0.035

    /** Gradient magnitude above which a pixel counts as sitting on an edge. */
    private const val EDGE_THRESHOLD = 26

    sealed interface Result {
        data object Accepted : Result
        data class Rejected(val message: String) : Result
    }

    data class Analysis(val meanLuma: Double, val lumaStdDev: Double, val edgeRatio: Double)

    fun validate(bitmap: Bitmap): Result {
        val analysis = analyse(bitmap) ?: return Result.Accepted // Unreadable: give benefit of doubt.

        return when {
            analysis.meanLuma < MIN_MEAN_LUMA ->
                Result.Rejected("Too dark to tell. Turn a light on and point it at your desk.")

            analysis.meanLuma > MAX_MEAN_LUMA ->
                Result.Rejected("That's just glare. Point it at what you're about to work on.")

            analysis.lumaStdDev < MIN_LUMA_STD_DEV && analysis.edgeRatio < MIN_EDGE_RATIO ->
                Result.Rejected("That doesn't look like a desk. Point it at what you're about to work on.")

            analysis.edgeRatio < MIN_EDGE_RATIO / 2 ->
                Result.Rejected("That doesn't look like a desk. Point it at what you're about to work on.")

            else -> Result.Accepted
        }
    }

    /** Exposed so you can log real numbers while calibrating. */
    fun analyse(bitmap: Bitmap): Analysis? {
        val small = downscale(bitmap) ?: return null
        val width = small.width
        val height = small.height
        if (width < 8 || height < 8) return null

        val pixels = IntArray(width * height)
        small.getPixels(pixels, 0, width, 0, 0, width, height)
        if (small !== bitmap) small.recycle()

        val luma = IntArray(pixels.size) { index ->
            val pixel = pixels[index]
            // Rec. 601 luma, integer-only. Perceptual accuracy is irrelevant at this
            // level of decision; speed on a cold 7am CPU is not.
            val r = (pixel shr 16) and 0xFF
            val g = (pixel shr 8) and 0xFF
            val b = pixel and 0xFF
            (r * 299 + g * 587 + b * 114) / 1000
        }

        var sum = 0L
        for (value in luma) sum += value
        val mean = sum.toDouble() / luma.size

        var variance = 0.0
        for (value in luma) {
            val delta = value - mean
            variance += delta * delta
        }
        val stdDev = sqrt(variance / luma.size)

        // Cheap central-difference gradient. A full Sobel buys nothing at this threshold.
        var edgeCount = 0
        for (y in 1 until height - 1) {
            val row = y * width
            for (x in 1 until width - 1) {
                val index = row + x
                val gx = abs(luma[index + 1] - luma[index - 1])
                val gy = abs(luma[index + width] - luma[index - width])
                if (gx + gy >= EDGE_THRESHOLD) edgeCount++
            }
        }
        val interiorCount = (width - 2) * (height - 2)
        val edgeRatio = if (interiorCount > 0) edgeCount.toDouble() / interiorCount else 0.0

        return Analysis(meanLuma = mean, lumaStdDev = stdDev, edgeRatio = edgeRatio)
    }

    private fun downscale(bitmap: Bitmap): Bitmap? = runCatching {
        val longest = maxOf(bitmap.width, bitmap.height)
        if (longest <= SAMPLE_SIZE) return@runCatching bitmap
        val factor = SAMPLE_SIZE.toDouble() / longest
        bitmap.scale(
            width = (bitmap.width * factor).toInt().coerceAtLeast(1),
            height = (bitmap.height * factor).toInt().coerceAtLeast(1),
        )
    }.getOrNull()
}

/*
 * ─────────────────────────────────────────────────────────────────────────────────────
 * Why there is no server call here, and why you should not add one later
 * ─────────────────────────────────────────────────────────────────────────────────────
 * The iOS comment leaves the door open to "on-device first, LLM second". On Android that
 * door stays shut for v1, for three reasons that all point the same way:
 *
 *   1. Latency. ProofView has an 8-second budget end to end. A round trip at 7am on
 *      whatever network the user is on blows it.
 *   2. Trust. "This app photographs my desk and uploads it" is a Play data-safety
 *      disclosure, a privacy-policy section, and a support burden. Right now the honest
 *      disclosure is *no data leaves the device*, which is also the better marketing line.
 *   3. Cost. Per-proof inference on a free tier is a bill that scales with the users who
 *      have not paid you yet.
 *
 * If a future version does add a model, it belongs behind the Pro entitlement and behind
 * an explicit opt-in, and this local pass stays as the first gate.
 */
