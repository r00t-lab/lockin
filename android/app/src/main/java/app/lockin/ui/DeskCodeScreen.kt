package app.lockin.ui

import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.FileProvider
import app.lockin.model.Commitment
import app.lockin.proof.DeskCode
import app.lockin.ui.theme.EyebrowText
import app.lockin.ui.theme.Lockin
import java.io.File
import java.io.FileOutputStream

/**
 * The desk sticker.
 *
 * ## Why this screen has to exist
 * Without it, "Scan your desk code" is a trap. The user picks it, the alarm fires, the
 * proof screen opens a scanner that only accepts this commitment's UUID — and nothing
 * anywhere in the app has ever shown them that code. They cannot prove, cannot stop the
 * nagging, and the app looks broken in the exact moment it is supposed to be trusted.
 * [DeskCode] has been able to draw the sticker since day one; nothing ever called it.
 *
 * ## Why it is the hardest proof mode, deliberately
 * Getting out of bed to scan a sticker on a desk is the whole mechanic. A photo can be
 * taken from under the duvet and a timer can be started there too; this one cannot. That
 * is also why the code is printed rather than kept on the phone — a sticker on the phone
 * defeats the only proof mode that requires the user to be somewhere.
 */
@Composable
fun DeskCodeScreen(
    commitment: Commitment,
    onFinish: () -> Unit,
) {
    val palette = Lockin.palette
    val context = LocalContext.current

    // Drawn once per commitment. The bitmap is 720px so the shared copy is worth printing
    // rather than a screen-sized blur that fails to scan off paper.
    val code = remember(commitment.id) { DeskCode.bitmap(commitment.id) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.ground)
            .systemBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text("YOUR DESK CODE", style = EyebrowText, color = palette.ink3)
        Spacer(Modifier.height(10.dp))

        Text(
            commitment.title,
            fontSize = 22.sp,
            lineHeight = 28.sp,
            fontWeight = FontWeight.Medium,
            color = palette.ink,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(24.dp))

        if (code != null) {
            // White plate under the code, always. The dark theme's ground is nearly black
            // and a QR drawn straight onto it is unreadable to every scanner including
            // this app's own.
            Image(
                bitmap = code.asImageBitmap(),
                contentDescription = "Desk code for ${commitment.title}",
                modifier = Modifier
                    .size(260.dp)
                    .background(androidx.compose.ui.graphics.Color.White, RoundedCornerShape(14.dp))
                    .padding(14.dp),
            )
        } else {
            Text(
                "Couldn't draw the code",
                fontSize = 14.sp,
                color = palette.alarm,
                textAlign = TextAlign.Center,
            )
        }

        Spacer(Modifier.height(22.dp))

        Text(
            "Print it, or screenshot it and prop the screen where you work. When the " +
                "alarm goes off, the only way to stop it is to be close enough to scan this.",
            fontSize = 13.sp,
            lineHeight = 20.sp,
            color = palette.ink2,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(26.dp))

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(9.dp),
        ) {
            if (code != null) {
                Button(
                    onClick = { shareDeskCode(context, code, commitment.title) },
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(11.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = palette.ink,
                        contentColor = palette.ground,
                    ),
                    contentPadding = PaddingValues(vertical = 15.dp),
                ) {
                    Text("Save or print", fontSize = 16.sp, fontWeight = FontWeight.Medium)
                }
            }

            TextButton(onClick = onFinish, modifier = Modifier.fillMaxWidth()) {
                Text("Done", fontSize = 15.sp, color = palette.ink2)
            }
        }
    }
}

/**
 * Hands the sticker to the system sheet, which is where Android keeps printing, saving to
 * Files, and every messaging app the user might send it to themselves through.
 *
 * The PNG goes to the cache directory the existing FileProvider already exposes. It is a
 * derived artifact — the code can be redrawn from the commitment id at any time — so
 * nothing is lost when the system clears it.
 */
private fun shareDeskCode(context: Context, code: Bitmap, title: String) {
    val file = File(context.cacheDir, "desk-code.png")
    runCatching {
        FileOutputStream(file).use { code.compress(Bitmap.CompressFormat.PNG, 100, it) }
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileprovider",
            file,
        )
        val intent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_SUBJECT, "Nagg desk code — $title")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(Intent.createChooser(intent, "Save or print"))
    }
}
