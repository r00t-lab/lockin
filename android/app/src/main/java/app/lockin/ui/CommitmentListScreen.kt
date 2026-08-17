package app.lockin.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.lockin.data.CommitmentStore
import app.lockin.model.Commitment
import app.lockin.ui.theme.EyebrowText
import app.lockin.ui.theme.Lockin
import app.lockin.ui.theme.MetaText
import app.lockin.ui.theme.StatNumber
import java.time.LocalTime
import java.time.format.DateTimeFormatter
import java.util.Locale

/**
 * Home screen. Deliberately boring — the product's personality lives in the alarm, not
 * here. A list, a streak, one button.
 *
 * Layout is a direct transcription of the prototype: wordmark row, three-column stats
 * strip with hairline dividers, then cards.
 */
@Composable
fun CommitmentListScreen(
    commitments: List<Commitment>,
    stats: CommitmentStore.Stats,
    warnings: List<AlarmWarning>,
    onAdd: () -> Unit,
    onDelete: (Commitment) -> Unit,
    onOpenProof: (Commitment) -> Unit,
) {
    val palette = Lockin.palette

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.ground)
            .systemBarsPadding(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 20.dp, end = 12.dp, top = 18.dp, bottom = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Row {
                Text(
                    "lock",
                    style = MetaText.copy(fontSize = 17.sp, fontWeight = FontWeight.SemiBold),
                    color = palette.ink,
                )
                Text(
                    "in",
                    style = MetaText.copy(fontSize = 17.sp, fontWeight = FontWeight.SemiBold),
                    color = palette.alarm,
                )
            }

            IconButton(
                onClick = onAdd,
                modifier = Modifier
                    .size(34.dp)
                    .border(1.dp, palette.line, CircleShape),
            ) {
                Icon(Icons.Filled.Add, contentDescription = "New commitment", tint = palette.ink)
            }
        }

        StatsRow(stats)

        LazyColumn(
            modifier = Modifier.weight(1f),
            contentPadding = androidx.compose.foundation.layout.PaddingValues(
                start = 20.dp,
                end = 20.dp,
                top = 18.dp,
                bottom = 24.dp,
            ),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            items(warnings, key = { it.id }) { warning ->
                WarningBanner(warning)
            }

            if (commitments.isEmpty()) {
                item { EmptyState() }
            }

            items(commitments, key = { it.id }) { commitment ->
                CommitmentCard(
                    commitment = commitment,
                    onClick = { onOpenProof(commitment) },
                    onDelete = { onDelete(commitment) },
                )
            }
        }
    }
}

@Composable
private fun StatsRow(stats: CommitmentStore.Stats) {
    val palette = Lockin.palette
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.line)
            .padding(vertical = 1.dp),
        horizontalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        Stat(stats.bestStreak.toString(), "STREAK", Modifier.weight(1f))
        Stat(stats.proved.toString(), "TODAY", Modifier.weight(1f))
        Stat(stats.missed.toString(), "EXCUSES", Modifier.weight(1f))
    }
}

@Composable
private fun Stat(value: String, label: String, modifier: Modifier = Modifier) {
    val palette = Lockin.palette
    Column(
        modifier = modifier
            .background(palette.ground)
            .padding(vertical = 12.dp, horizontal = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(value, style = StatNumber, color = palette.ink)
        Text(label, style = EyebrowText, color = palette.ink3)
    }
}

@Composable
private fun CommitmentCard(
    commitment: Commitment,
    onClick: () -> Unit,
    onDelete: () -> Unit,
) {
    val palette = Lockin.palette
    val done = commitment.isDoneToday

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = if (done) palette.goBg else palette.surface,
                shape = RoundedCornerShape(14.dp),
            )
            .border(
                width = 1.dp,
                color = if (done) palette.goBg else palette.line,
                shape = RoundedCornerShape(14.dp),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp)
            .alpha(if (commitment.isEnabled) 1f else 0.4f),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                text = commitment.title,
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = if (done) palette.go else palette.ink,
                textDecoration = if (done) TextDecoration.LineThrough else null,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(3.dp))
            Text(
                text = "${commitment.formattedTime()}  ·  ${commitment.proofKind.shortLabel}" +
                    if (commitment.repeats.isRecurring) "  ·  repeats" else "",
                style = MetaText,
                color = if (done) palette.go else palette.ink2,
            )
        }

        if (commitment.currentStreak > 0) {
            Text(
                text = commitment.currentStreak.toString(),
                style = MetaText.copy(fontSize = 15.sp, fontWeight = FontWeight.SemiBold),
                color = if (done) palette.go else palette.ink,
                modifier = Modifier.padding(horizontal = 10.dp),
            )
        }

        IconButton(onClick = onDelete, modifier = Modifier.size(32.dp)) {
            Icon(
                Icons.Filled.Close,
                contentDescription = "Delete",
                tint = palette.ink3,
                modifier = Modifier.size(18.dp),
            )
        }
    }
}

@Composable
private fun EmptyState() {
    val palette = Lockin.palette
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, palette.line, RoundedCornerShape(14.dp))
            .padding(horizontal = 22.dp, vertical = 34.dp),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "Nothing is holding you accountable.\nAdd the thing you keep putting off.",
            fontSize = 14.sp,
            lineHeight = 22.sp,
            color = palette.ink2,
            textAlign = TextAlign.Center,
        )
    }
}

/**
 * A permission or OS setting that will make the alarm fail. Shown as a card in the list
 * rather than a dialog, because a dialog on launch is exactly what we promised not to do —
 * but silently shipping a broken alarm is worse than either.
 */
data class AlarmWarning(
    val id: String,
    val message: String,
    val actionLabel: String,
    val onAction: () -> Unit,
)

@Composable
private fun WarningBanner(warning: AlarmWarning) {
    val palette = Lockin.palette
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.alarm.copy(alpha = 0.12f), RoundedCornerShape(14.dp))
            .clickable(onClick = warning.onAction)
            .padding(16.dp),
    ) {
        Text(warning.message, fontSize = 13.sp, lineHeight = 20.sp, color = palette.ink)
        Spacer(Modifier.height(8.dp))
        Text(
            warning.actionLabel,
            fontSize = 13.sp,
            fontWeight = FontWeight.SemiBold,
            color = palette.alarm,
        )
    }
}

private val timeFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("HH:mm", Locale.US)

private fun Commitment.formattedTime(): String =
    LocalTime.of(hour, minute).format(timeFormatter)
