package app.lockin.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TimePicker
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.lockin.model.Commitment
import app.lockin.model.Weekdays
import app.lockin.ui.theme.EyebrowText
import app.lockin.ui.theme.Lockin
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

/**
 * Creating a commitment is the point of highest intent in the app. Three fields, one
 * screen, no navigation stack.
 *
 * Permission prompts belong *after* this screen, not before it — the user has to want the
 * alarm before being asked to allow it.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NewCommitmentSheet(
    onCancel: () -> Unit,
    onSave: (Commitment) -> Unit,
    /**
     * The commitment being changed, or null when creating one.
     *
     * Editing copies onto the existing record rather than building a new one, which is
     * the whole point: a user who moves an alarm from 7:00 to 7:15 has not abandoned the
     * habit, and rebuilding the commitment would reset the streak they are protecting.
     * That is the one thing this app must never do by accident.
     */
    editing: Commitment? = null,
) {
    val palette = Lockin.palette

    var title by remember { mutableStateOf(editing?.title.orEmpty()) }
    var showTitleError by remember { mutableStateOf(false) }
    var weekdays by remember { mutableStateOf(editing?.repeats?.weekdays ?: emptySet()) }
    var proofKind by remember {
        mutableStateOf(editing?.proofKind ?: Commitment.ProofKind.PHOTO)
    }

    val timeState = rememberTimePickerState(
        initialHour = editing?.hour ?: 19,
        initialMinute = editing?.minute ?: 0,
        is24Hour = true,
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.ground)
            .systemBarsPadding()
            .imePadding()
            .padding(horizontal = 20.dp, vertical = 24.dp),
    ) {
        Text(
            if (editing == null) "New commitment" else "Edit commitment",
            fontSize = 20.sp,
            fontWeight = FontWeight.Medium,
            color = palette.ink,
        )

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState()),
        ) {
            FieldLabel("WHAT ARE YOU STARTING")
            OutlinedTextField(
                value = title,
                onValueChange = {
                    title = it
                    showTitleError = false
                },
                placeholder = { Text("Write the essay intro", color = palette.ink3) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Done),
                shape = RoundedCornerShape(11.dp),
                modifier = Modifier.fillMaxWidth(),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = palette.surface,
                    unfocusedContainerColor = palette.surface,
                    focusedTextColor = palette.ink,
                    unfocusedTextColor = palette.ink,
                ),
            )
            if (showTitleError) {
                Spacer(Modifier.height(8.dp))
                Text(
                    "Write what you'll actually do first.",
                    fontSize = 13.sp,
                    color = palette.alarm,
                )
            }

            FieldLabel("TIME")
            Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                TimePicker(state = timeState)
            }

            FieldLabel("REPEAT — LEAVE EMPTY FOR ONCE")
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                // 1 = Sunday … 7 = Saturday, matching Commitment.Repeat.
                (1..7).forEach { day ->
                    val isOn = day in weekdays
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(38.dp)
                            .background(
                                if (isOn) palette.ink else palette.sunk,
                                CircleShape,
                            )
                            .clickable {
                                weekdays = if (isOn) weekdays - day else weekdays + day
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            Weekdays.symbols[day - 1],
                            color = if (isOn) palette.ground else palette.ink2,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.Medium,
                        )
                    }
                }
            }

            FieldLabel("HOW YOU'LL PROVE IT")
            Commitment.ProofKind.entries.forEach { kind ->
                ProofOption(
                    label = kind.label,
                    selected = proofKind == kind,
                    onClick = { proofKind = kind },
                )
                Spacer(Modifier.height(8.dp))
            }
        }

        Button(
            onClick = {
                val trimmed = title.trim()
                if (trimmed.isEmpty()) {
                    showTitleError = true
                    return@Button
                }
                onSave(
                    editing?.copy(
                        title = trimmed,
                        fireAtMillis = millisFor(timeState.hour, timeState.minute),
                        repeats = Commitment.Repeat(weekdays),
                        proofKind = proofKind,
                    ) ?: Commitment(
                        title = trimmed,
                        fireAtMillis = millisFor(timeState.hour, timeState.minute),
                        repeats = Commitment.Repeat(weekdays),
                        proofKind = proofKind,
                    ),
                )
            },
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 22.dp),
            shape = RoundedCornerShape(11.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = palette.ink,
                contentColor = palette.ground,
            ),
            contentPadding = PaddingValues(vertical = 15.dp),
        ) {
            Text("Lock it in", fontSize = 15.sp, fontWeight = FontWeight.Medium)
        }

        OutlinedButton(
            onClick = onCancel,
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 9.dp),
            shape = RoundedCornerShape(11.dp),
            colors = ButtonDefaults.outlinedButtonColors(contentColor = palette.ink),
            contentPadding = PaddingValues(vertical = 13.dp),
        ) {
            Text("Cancel", fontSize = 15.sp)
        }
    }
}

@Composable
private fun FieldLabel(text: String) {
    Text(
        text = text,
        style = EyebrowText,
        color = Lockin.palette.ink3,
        modifier = Modifier.padding(top = 16.dp, bottom = 7.dp),
    )
}

@Composable
private fun ProofOption(label: String, selected: Boolean, onClick: () -> Unit) {
    val palette = Lockin.palette
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                if (selected) palette.goBg else palette.surface,
                RoundedCornerShape(11.dp),
            )
            .border(
                1.dp,
                if (selected) palette.go else palette.line,
                RoundedCornerShape(11.dp),
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(16.dp)
                .background(
                    if (selected) palette.go else androidx.compose.ui.graphics.Color.Transparent,
                    CircleShape,
                )
                .border(1.dp, if (selected) palette.go else palette.line, CircleShape),
        )
        Spacer(Modifier.padding(horizontal = 6.dp))
        Text(
            label,
            fontSize = 15.sp,
            color = if (selected) palette.go else palette.ink,
        )
    }
}

/**
 * Compose gives us hour/minute; [Commitment] stores an absolute instant. Anchor it to
 * today so a one-off created at 14:00 for 19:00 fires tonight, and let
 * [AlarmService.nextTriggerMillis][app.lockin.alarm.AlarmService.Companion.nextTriggerMillis]
 * roll it forward if the time has already gone.
 */
private fun millisFor(hour: Int, minute: Int): Long =
    LocalDate.now()
        .atTime(LocalTime.of(hour, minute))
        .atZone(ZoneId.systemDefault())
        .toInstant()
        .toEpochMilli()
