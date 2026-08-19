package app.lockin.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.lockin.model.Commitment
import app.lockin.ui.theme.EyebrowText
import app.lockin.ui.theme.Lockin
import app.lockin.ui.theme.MetaText
import app.lockin.ui.theme.StatNumber
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/**
 * The report the onboarding and the paywall both promise: "every excuse you made".
 *
 * It existed as a sentence in two pieces of marketing copy and nowhere in the app. That is
 * worse than not promising it — a subscriber who goes looking for the thing they paid for
 * and cannot find it asks for a refund, and is right to.
 *
 * ## What it can honestly show
 * The store keeps aggregates, not a diary: a current streak, a best, a miss count, and the
 * last time proof landed. So this screen shows exactly that and does not fake a seven-day
 * grid it has no data for. If per-day history is wanted later it has to be recorded first
 * — inventing squares from a total would be a chart that lies.
 *
 * ## Tone
 * Blunt, never cruel. The product's whole position is that it is the one app that does not
 * let you off, and a report that congratulates someone for a zero-day streak throws that
 * away. But it is a study app, not a punishment: no shame language, no red numbers on a
 * day someone did fine.
 */
@Composable
fun WeeklyReportScreen(
    commitments: List<Commitment>,
    onFinish: () -> Unit,
) {
    val palette = Lockin.palette
    val real = commitments.filterNot { it.isRehearsal }
    val totalExcuses = real.sumOf { it.missCount }
    val bestStreak = real.maxOfOrNull { it.bestStreak } ?: 0

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.ground)
            .systemBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 26.dp),
    ) {
        Text("THE RECEIPTS", style = EyebrowText, color = palette.ink3)
        Spacer(Modifier.height(10.dp))

        Text(
            text = headline(real.isEmpty(), totalExcuses),
            fontSize = 26.sp,
            lineHeight = 32.sp,
            fontWeight = FontWeight.Medium,
            color = palette.ink,
        )

        Spacer(Modifier.height(10.dp))

        Text(
            text = if (real.isEmpty()) {
                "Nothing to report yet. Add a commitment and this fills itself in."
            } else {
                subhead(totalExcuses, bestStreak)
            },
            fontSize = 15.sp,
            lineHeight = 22.sp,
            color = palette.ink2,
        )

        if (real.isNotEmpty()) {
            Spacer(Modifier.height(24.dp))
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                real.forEach { ReportRow(it) }
            }
        }

        Spacer(Modifier.height(28.dp))
        TextButton(onClick = onFinish, modifier = Modifier.fillMaxWidth()) {
            Text("Close", fontSize = 15.sp, color = palette.ink2)
        }
    }
}

// The headline is the one number the user did not want to see. Zero excuses is worth
// saying plainly rather than dressing up — the number is the compliment.
private fun headline(isEmpty: Boolean, excuses: Int): String = when {
    isEmpty -> "Nothing on the record."
    excuses == 0 -> "Zero excuses on the record."
    excuses == 1 -> "One excuse on the record."
    else -> "$excuses excuses on the record."
}

private fun subhead(excuses: Int, bestStreak: Int): String = when {
    excuses > 0 ->
        "Every one of these is an alarm that rang and a thing that did not get started."
    bestStreak > 0 -> "Best run so far: $bestStreak days. Nagg has nothing on you."
    else -> "Nothing missed yet. The first week is the easy one."
}

@Composable
private fun ReportRow(commitment: Commitment) {
    val palette = Lockin.palette
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.surface, RoundedCornerShape(14.dp))
            .border(1.dp, palette.line, RoundedCornerShape(14.dp))
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        Text(
            commitment.title,
            fontSize = 15.sp,
            fontWeight = FontWeight.Medium,
            color = palette.ink,
        )

        Row(Modifier.fillMaxWidth()) {
            Figure(
                commitment.currentStreak.toString(),
                "now",
                if (commitment.currentStreak > 0) palette.go else palette.ink3,
                Modifier.weight(1f),
            )
            Figure(commitment.bestStreak.toString(), "best", palette.ink, Modifier.weight(1f))
            Figure(
                commitment.missCount.toString(),
                "excuses",
                if (commitment.missCount > 0) palette.alarm else palette.ink3,
                Modifier.weight(1f),
            )
        }

        Text(lastProved(commitment), style = MetaText.copy(fontSize = 11.sp), color = palette.ink3)
    }
}

@Composable
private fun Figure(
    value: String,
    label: String,
    tint: androidx.compose.ui.graphics.Color,
    modifier: Modifier = Modifier,
) {
    val palette = Lockin.palette
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(value, style = StatNumber.copy(fontSize = 20.sp), color = tint)
        Text(label.uppercase(), style = EyebrowText, color = palette.ink3)
    }
}

private fun lastProved(commitment: Commitment): String {
    val millis = commitment.lastCompletedAtMillis ?: return "never proved"
    val zone = ZoneId.systemDefault()
    val date = Instant.ofEpochMilli(millis).atZone(zone).toLocalDate()
    val today = LocalDate.now(zone)
    return when (date) {
        today -> "proved today"
        today.minusDays(1) -> "proved yesterday"
        else -> "last proved " + date.format(DateTimeFormatter.ofPattern("d MMM yyyy"))
    }
}
