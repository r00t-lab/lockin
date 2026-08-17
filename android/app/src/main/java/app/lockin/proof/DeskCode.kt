package app.lockin.proof

import android.graphics.Bitmap
import android.graphics.Color
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.qrcode.QRCodeWriter
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import java.util.UUID

/**
 * The printable desk sticker.
 *
 * Payload is the commitment's UUID and nothing else — no URL, no JSON, no version prefix.
 * The scanner compares it with a plain string equality check, which means the sticker
 * cannot be "nearly right", and it means a code screenshotted from someone else's phone
 * is useless. Keep it that way.
 */
object DeskCode {

    /**
     * Error correction is deliberately HIGH. This code gets printed on an inkjet, taped
     * to a desk, and scanned in bad light by someone who has just woken up. Redundancy is
     * cheaper than a failed proof.
     */
    fun bitmap(commitmentId: UUID, sizePx: Int = 720): Bitmap? = runCatching {
        val hints = mapOf(
            EncodeHintType.ERROR_CORRECTION to ErrorCorrectionLevel.H,
            EncodeHintType.MARGIN to 2,
            EncodeHintType.CHARACTER_SET to "UTF-8",
        )

        val matrix = QRCodeWriter().encode(
            commitmentId.toString(),
            BarcodeFormat.QR_CODE,
            sizePx,
            sizePx,
            hints,
        )

        val pixels = IntArray(matrix.width * matrix.height)
        for (y in 0 until matrix.height) {
            val row = y * matrix.width
            for (x in 0 until matrix.width) {
                pixels[row + x] = if (matrix.get(x, y)) Color.BLACK else Color.WHITE
            }
        }

        Bitmap.createBitmap(matrix.width, matrix.height, Bitmap.Config.ARGB_8888).apply {
            setPixels(pixels, 0, matrix.width, 0, 0, matrix.width, matrix.height)
        }
    }.getOrNull()
}
