package app.portermills.features.calendar

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DatePicker
import androidx.compose.material3.DatePickerDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TimePicker
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.rememberDatePickerState
import androidx.compose.material3.rememberTimePickerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import app.portermills.ui.components.ConfirmDialog
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

private val dateFormat = DateTimeFormatter.ofPattern("EEE d MMM yyyy")
private val timeFormat = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)

private enum class Picker { StartDate, StartTime, EndDate, EndTime }

/** Full-screen dialog for creating ([event] null) or editing an event. */
@Composable
fun EventEditor(
    event: CalendarEvent?,
    date: LocalDate,
    onDismiss: () -> Unit,
    onSave: (EventRequest) -> Unit,
    onDelete: () -> Unit,
) {
    var title by remember { mutableStateOf(event?.title.orEmpty()) }
    var description by remember { mutableStateOf(event?.description.orEmpty()) }
    var allDay by remember { mutableStateOf(event?.allDay ?: false) }
    var start by remember {
        mutableStateOf(event?.start?.toLocalDateTime() ?: date.atTime(LocalTime.now().hour, 0).plusHours(1))
    }
    var end by remember {
        mutableStateOf(event?.end?.toLocalDateTime() ?: date.atTime(LocalTime.now().hour, 0).plusHours(2))
    }
    var picker by remember { mutableStateOf<Picker?>(null) }
    var confirmDelete by remember { mutableStateOf(false) }

    // Keep the end at or after the start, preserving the event's length.
    fun moveStart(newStart: LocalDateTime) {
        val length = java.time.Duration.between(start, end)
        start = newStart
        end = newStart.plus(length)
    }

    fun moveEnd(newEnd: LocalDateTime) {
        end = if (newEnd.isBefore(start)) start else newEnd
    }

    fun request(): EventRequest {
        val zone = ZoneId.systemDefault()
        // All-day events run from the first day's midnight to the last day's final second.
        val from = if (allDay) start.toLocalDate().atStartOfDay() else start
        val to = if (allDay) end.toLocalDate().atTime(23, 59, 59) else end
        return EventRequest(
            title = title.trim(),
            description = description.trim(),
            startsAt = from.atZone(zone).toInstant().toString(),
            endsAt = to.atZone(zone).toInstant().toString(),
            allDay = allDay,
        )
    }

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(if (event == null) "New event" else "Edit event") },
                    navigationIcon = {
                        IconButton(onClick = onDismiss) { Icon(Icons.Default.Close, "Cancel") }
                    },
                    actions = {
                        TextButton(onClick = { onSave(request()) }, enabled = title.isNotBlank()) {
                            Text("Save")
                        }
                    },
                )
            },
        ) { padding ->
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .imePadding()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
            ) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("Title") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                    modifier = Modifier.fillMaxWidth(),
                )

                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("All day", style = MaterialTheme.typography.bodyLarge)
                    Spacer(Modifier.weight(1f))
                    Switch(checked = allDay, onCheckedChange = { allDay = it })
                }

                DateTimeRow("Starts", start, allDay, { picker = Picker.StartDate }, { picker = Picker.StartTime })
                DateTimeRow("Ends", end, allDay, { picker = Picker.EndDate }, { picker = Picker.EndTime })

                OutlinedTextField(
                    value = description,
                    onValueChange = { description = it },
                    label = { Text("Notes") },
                    minLines = 3,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                    modifier = Modifier.fillMaxWidth(),
                )

                if (event != null) {
                    TextButton(onClick = { confirmDelete = true }) {
                        Text("Delete event", color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
    }

    when (picker) {
        Picker.StartDate -> DatePick(start.toLocalDate(), { picker = null }) { moveStart(it.atTime(start.toLocalTime())) }
        Picker.EndDate -> DatePick(end.toLocalDate(), { picker = null }) { moveEnd(it.atTime(end.toLocalTime())) }
        Picker.StartTime -> TimePick(start.toLocalTime(), { picker = null }) { moveStart(start.toLocalDate().atTime(it)) }
        Picker.EndTime -> TimePick(end.toLocalTime(), { picker = null }) { moveEnd(end.toLocalDate().atTime(it)) }
        null -> Unit
    }

    if (confirmDelete) {
        ConfirmDialog(
            title = "Delete event?",
            message = "\"${event?.title}\" will be removed for everyone.",
            onDismiss = { confirmDelete = false },
            onConfirm = { confirmDelete = false; onDelete() },
        )
    }
}

@Composable
private fun DateTimeRow(
    label: String,
    value: LocalDateTime,
    allDay: Boolean,
    onDate: () -> Unit,
    onTime: () -> Unit,
) {
    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(label, style = MaterialTheme.typography.bodyLarge, modifier = Modifier.weight(1f))
        OutlinedButton(onClick = onDate) { Text(value.format(dateFormat)) }
        if (!allDay) OutlinedButton(onClick = onTime) { Text(value.format(timeFormat)) }
    }
}

@Composable
private fun DatePick(initial: LocalDate, onDismiss: () -> Unit, onPick: (LocalDate) -> Unit) {
    // The Material date picker works in UTC milliseconds.
    val state = rememberDatePickerState(
        initialSelectedDateMillis = initial.atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    )
    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                state.selectedDateMillis?.let { onPick(Instant.ofEpochMilli(it).atZone(ZoneOffset.UTC).toLocalDate()) }
                onDismiss()
            }) { Text("OK") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    ) {
        DatePicker(state)
    }
}

@Composable
private fun TimePick(initial: LocalTime, onDismiss: () -> Unit, onPick: (LocalTime) -> Unit) {
    val state = rememberTimePickerState(initialHour = initial.hour, initialMinute = initial.minute)
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = {
                onPick(LocalTime.of(state.hour, state.minute))
                onDismiss()
            }) { Text("OK") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
        text = { TimePicker(state) },
    )
}
