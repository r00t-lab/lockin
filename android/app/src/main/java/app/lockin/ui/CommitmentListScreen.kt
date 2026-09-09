package app.lockin.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.QrCode2
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.OutlinedButton
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
@OptIn(androidx.compose.foundation.ExperimentalFoundationApi::class)
@Composable
fun CommitmentListScreen(
    commitments: List<Commitment>,
    stats: CommitmentStore.Stats,
    warnings: List<AlarmWarning>,
    onAdd: () -> Unit,
    onDelete: (Commitment) -> Unit,
    onOpenProof: (Commitment) -> Unit,
    onEdit: (Commitment) -> Unit = {},
    needsProof: (Commitment) -> Boolean = { false },
    unarmed: (Commitment) -> Boolean = { false },
    onRearm: (Commitment) -> Unit = {},
    onOpenDeskCode: (Commitment) -> Unit = {},
    onOpenReport: () -> Unit = {},
    onOpenDiagnostics: () -> Unit = {},
    onRehearse: () -> Unit = {},
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
            // Long-press opens diagnostics, same as iOS: the one gesture that is worth
            // knowing when an alarm does not ring on a device nobody can attach a
            // debugger to.
            Row(
                modifier = Modifier.combinedClickable(
                    onClick = {},
                    onLongClick = onOpenDiagnostics,
                ),
            ) {
                Text(
                    "na",
                    style = MetaText.copy(fontSize = 17.sp, fontWeight = FontWeight.SemiBold),
                    color = palette.ink,
                )
                Text(
                    "gg",
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

        StatsRow(stats, onClick = onOpenReport)

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
                    owed = needsProof(commitment),
                    unarmed = unarmed(commitment),
                    onRearm = { onRearm(commitment) },
                    onClick = { onEdit(commitment) },
                    onProve = { onOpenProof(commitment) },
                    onDelete = { onDelete(commitment) },
                    onShowDeskCode = { onOpenDeskCode(commitment) },
                )
            }
        }

        // Only before the first commitment, matching iOS. Its whole job is to prove the
        // alarm is not a bluff to someone who has not committed to anything yet; once a
        // real row exists that question is answered and the rail is just a button
        // competing with the user's own commitments. It returns if the list is emptied.
        if (commitments.none { !it.isRehearsal }) {
            RehearsalFooter(
                armed = commitments.any { it.isRehearsal },
                onRehearse = onRehearse,
            )
        }
    }
}

/**
 * The demo button, and the only honest way to earn trust before the first 7am.
 *
 * Someone who has just installed an alarm that claims to beat Do Not Disturb has no
 * reason to believe it, and the alternative to this button is asking them to set one for
 * tomorrow morning and find out the hard way. Twenty seconds is cheaper than a night.
 */
@Composable
private fun RehearsalFooter(armed: Boolean, onRehearse: () -> Unit) {
    val palette = Lockin.palette
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 20.dp)
            .padding(bottom = 18.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        OutlinedButton(
            onClick = onRehearse,
            enabled = !armed,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(11.dp),
        ) {
            Text(
                // Names the cost instead of the concept, as on iOS: "rehearse" asks the
                // reader to work out what that is and how long it takes before deciding.
                if (armed) "Rehearsal armed" else "Try it now — rings in 20 seconds",
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = if (armed) palette.go else palette.ink,
            )
        }
        Spacer(Modifier.height(8.dp))
        Text(
            "Then again every 30 seconds, five times over — the real thing on fast-forward. "
                + "Put the phone down and prove nothing; that's the part worth watching.",
            fontSize = 12.sp,
            lineHeight = 18.sp,
            color = palette.ink3,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun StatsRow(stats: CommitmentStore.Stats, onClick: () -> Unit) {
    val palette = Lockin.palette
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .background(palette.line)
            .clickable(onClick = onClick)
            .padding(vertical = 1.dp),
        horizontalArrangement = Arrangement.spacedBy(1.dp),
    ) {
        Stat(stats.bestStreak.toString(), "STREAK", Modifier.weight(1f))
        Stat(stats.proved.toString(), "TODAY", Modifier.weight(1f))
        Stat(stats.missed.toString(), "EXCUSES", Modifier.weight(1f))
        ReportCue()
    }
}

/**
 * The affordance that says the strip opens something.
 *
 * The strip was tappable with nothing to say so, and App Review rejected the iOS build
 * under 2.3 for a weekly report it could not find. A tap target with no label is a tap
 * target nobody finds, on either platform. Intrinsic width, not an overlay: it takes its
 * own space instead of being painted over the excuses count.
 */
@Composable
private fun ReportCue() {
    val palette = Lockin.palette
    Row(
        modifier = Modifier
            .fillMaxHeight()
            .background(palette.ground)
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("REPORT", style = EyebrowText, color = palette.ink3)
        Spacer(Modifier.width(3.dp))
        Icon(
            imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
            contentDescription = null,
            tint = palette.ink3,
            modifier = Modifier.size(14.dp),
        )
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
    owed: Boolean,
    unarmed: Boolean = false,
    onRearm: () -> Unit = {},
    onClick: () -> Unit,
    onProve: () -> Unit,
    onDelete: () -> Unit,
    onShowDeskCode: () -> Unit = {},
) {
    val palette = Lockin.palette
    val done = commitment.isDoneToday

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                color = if (done) palette.goBg else palette.surface,
                shape = RoundedCornerShape(14.dp),
            )
            .border(
                width = 1.dp,
                color = when {
                    owed || unarmed -> palette.alarm
                    done -> palette.goBg
                    else -> palette.line
                },
                shape = RoundedCornerShape(14.dp),
            )
            // The body opens the editor. No pencil icon: the row is already the thing the
            // user is looking at, and the taps that must not land by accident -- delete,
            // and proof while an alarm is ringing -- have their own targets.
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 14.dp)
            .alpha(if (commitment.isEnabled) 1f else 0.4f),
    ) {
    Row(verticalAlignment = Alignment.CenterVertically) {
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
                // A row that looks healthy while being switched off is the single most
                // dangerous thing this list can show, so "no alarm" outranks everything
                // else it could say.
                text = if (unarmed) {
                    "No alarm set — this will not ring"
                } else if (owed) {
                    "Ringing — you haven't proved it"
                } else if (commitment.isRehearsal) {
                    "REHEARSAL  ·  ${commitment.proofKind.shortLabel}"
                } else {
                    "${commitment.formattedTime()}  ·  ${commitment.proofKind.shortLabel}" +
                        if (commitment.repeats.isRecurring) "  ·  repeats" else ""
                },
                style = MetaText,
                color = when {
                    owed || unarmed || commitment.isRehearsal -> palette.alarm
                    done -> palette.go
                    else -> palette.ink2
                },
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

        // Without this the code is unreachable after the commitment is created, which is
        // the whole reason the proof mode was a dead end in the first place.
        if (commitment.proofKind == Commitment.ProofKind.DESK_CODE) {
            IconButton(onClick = onShowDeskCode, modifier = Modifier.size(32.dp)) {
                Icon(
                    Icons.Filled.QrCode2,
                    contentDescription = "Show the desk code for ${commitment.title}",
                    tint = palette.ink3,
                    modifier = Modifier.size(18.dp),
                )
            }
        }

        IconButton(onClick = onDelete, modifier = Modifier.size(32.dp)) {
            Icon(
                Icons.Filled.Close,
                contentDescription = "Delete ${commitment.title}",
                tint = palette.ink3,
                modifier = Modifier.size(18.dp),
            )
        }
    }

        // The route to proof that does not depend on the alarm's own button having
        // worked. On a phone where the full-screen intent was suppressed, this row is
        // the only way back into the proof screen -- and the user has an alarm that keeps
        // coming back until they find it.
        if (owed || unarmed) {
            Spacer(Modifier.height(12.dp))
            Button(
                onClick = if (owed) onProve else onRearm,
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(11.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = palette.alarm,
                    contentColor = androidx.compose.ui.graphics.Color.White,
                ),
                contentPadding = PaddingValues(vertical = 13.dp),
            ) {
                Text(
                    if (owed) "Prove you started" else "Set the alarm again",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
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
