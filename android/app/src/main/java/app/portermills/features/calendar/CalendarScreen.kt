package app.portermills.features.calendar

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Today
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.portermills.ui.components.AccountMenu
import app.portermills.ui.components.ErrorSnackbar
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.util.Locale

private val monthTitle = DateTimeFormatter.ofPattern("LLLL yyyy")
private val dayTitle = DateTimeFormatter.ofPattern("EEEE d MMMM")
private val timeFormat = DateTimeFormatter.ofLocalizedTime(FormatStyle.SHORT)

/** What the event editor is open on: a new event for a day, or an existing one. */
private sealed interface Editing {
    data class New(val date: LocalDate) : Editing
    data class Existing(val event: CalendarEvent) : Editing
}

@Composable
fun CalendarScreen(viewModel: CalendarViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    var editing by remember { mutableStateOf<Editing?>(null) }

    ErrorSnackbar(state.error, snackbar, viewModel::errorShown)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(state.month.format(monthTitle)) },
                actions = {
                    IconButton(onClick = viewModel::previousMonth) {
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, "Previous month")
                    }
                    IconButton(onClick = viewModel::today) { Icon(Icons.Default.Today, "Today") }
                    IconButton(onClick = viewModel::nextMonth) {
                        Icon(Icons.AutoMirrored.Filled.KeyboardArrowRight, "Next month")
                    }
                    AccountMenu()
                },
            )
        },
        floatingActionButton = {
            FloatingActionButton(onClick = { editing = Editing.New(state.selected) }) {
                Icon(Icons.Default.Add, "Add event")
            }
        },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            MonthGrid(state, onSelect = viewModel::select)
            HorizontalDivider()
            Text(
                state.selected.format(dayTitle),
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 12.dp),
            )
            if (state.selectedEvents.isEmpty()) {
                Text(
                    "Nothing planned",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
            }
            LazyColumn(Modifier.fillMaxSize()) {
                items(state.selectedEvents, key = { it.id }) { event ->
                    ListItem(
                        headlineContent = { Text(event.title) },
                        supportingContent = event.description?.takeIf { it.isNotBlank() }?.let { { Text(it) } },
                        overlineContent = { Text(event.timeLabel(state.selected)) },
                        modifier = Modifier.clickable { editing = Editing.Existing(event) },
                    )
                }
            }
        }
    }

    when (val target = editing) {
        null -> Unit
        is Editing.New -> EventEditor(
            event = null,
            date = target.date,
            onDismiss = { editing = null },
            onSave = { request -> viewModel.save(null, request); editing = null },
            onDelete = {},
        )
        is Editing.Existing -> EventEditor(
            event = target.event,
            date = target.event.start.toLocalDate(),
            onDismiss = { editing = null },
            onSave = { request -> viewModel.save(target.event, request); editing = null },
            onDelete = { viewModel.delete(target.event); editing = null },
        )
    }
}

private fun CalendarEvent.timeLabel(day: LocalDate): String = when {
    allDay -> "All day"
    start.toLocalDate() == day && end.toLocalDate() == day ->
        "${start.format(timeFormat)} – ${end.format(timeFormat)}"
    start.toLocalDate() == day -> "From ${start.format(timeFormat)}"
    end.toLocalDate() == day -> "Until ${end.format(timeFormat)}"
    else -> "All day"
}

@Composable
private fun MonthGrid(state: CalendarUiState, onSelect: (LocalDate) -> Unit) {
    val days = state.gridDays
    val today = LocalDate.now()

    Column(Modifier.padding(horizontal = 8.dp)) {
        Row(Modifier.fillMaxWidth()) {
            for (day in days.take(7)) {
                Text(
                    day.dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault()),
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f).padding(vertical = 4.dp),
                )
            }
        }
        for (week in days.chunked(7)) {
            Row(Modifier.fillMaxWidth()) {
                for (day in week) {
                    DayCell(
                        day = day,
                        inMonth = YearMonth.from(day) == state.month,
                        isToday = day == today,
                        isSelected = day == state.selected,
                        eventCount = state.eventsByDay[day]?.size ?: 0,
                        onClick = { onSelect(day) },
                        modifier = Modifier.weight(1f),
                    )
                }
            }
        }
    }
}

@Composable
private fun DayCell(
    day: LocalDate,
    inMonth: Boolean,
    isToday: Boolean,
    isSelected: Boolean,
    eventCount: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = MaterialTheme.colorScheme
    val description = buildString {
        append(day.format(dayTitle))
        if (eventCount > 0) append(", $eventCount ${if (eventCount == 1) "event" else "events"}")
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier
            .height(52.dp)
            .clip(MaterialTheme.shapes.small)
            .clickable(onClick = onClick)
            .semantics { contentDescription = description }
            .padding(top = 4.dp),
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(32.dp)
                .then(
                    when {
                        isSelected -> Modifier.background(colors.primary, CircleShape)
                        isToday -> Modifier.border(1.5.dp, colors.primary, CircleShape)
                        else -> Modifier
                    }
                ),
        ) {
            Text(
                day.dayOfMonth.toString(),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal,
                color = when {
                    isSelected -> colors.onPrimary
                    !inMonth -> colors.onSurfaceVariant.copy(alpha = 0.45f)
                    isToday -> colors.primary
                    else -> colors.onSurface
                },
            )
        }
        Row(
            horizontalArrangement = Arrangement.spacedBy(3.dp),
            modifier = Modifier.padding(top = 3.dp).height(6.dp),
        ) {
            repeat(minOf(eventCount, 3)) {
                Box(
                    Modifier
                        .size(5.dp)
                        .background(
                            if (inMonth) colors.tertiary else colors.tertiary.copy(alpha = 0.4f),
                            CircleShape,
                        )
                )
            }
        }
    }
}
