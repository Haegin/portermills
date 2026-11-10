package app.portermills.features.calendar

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.portermills.data.api.ApiClient
import app.portermills.data.api.attempt
import app.portermills.data.api.userMessage
import app.portermills.data.socket.PhoenixSocket
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters
import java.time.temporal.WeekFields
import java.util.Locale
import javax.inject.Inject

data class CalendarUiState(
    val month: YearMonth = YearMonth.now(),
    val selected: LocalDate = LocalDate.now(),
    val eventsByDay: Map<LocalDate, List<CalendarEvent>> = emptyMap(),
    val error: String? = null,
) {
    val firstDayOfWeek: DayOfWeek get() = WeekFields.of(Locale.getDefault()).firstDayOfWeek

    /** The 42 days shown in the month grid: six full weeks. */
    val gridDays: List<LocalDate>
        get() {
            val start = month.atDay(1).with(TemporalAdjusters.previousOrSame(firstDayOfWeek))
            return List(GRID_DAYS) { start.plusDays(it.toLong()) }
        }

    val selectedEvents: List<CalendarEvent> get() = eventsByDay[selected].orEmpty()

    companion object {
        const val GRID_DAYS = 42
    }
}

@HiltViewModel
class CalendarViewModel @Inject constructor(
    private val api: ApiClient,
    socket: PhoenixSocket,
) : ViewModel() {
    private val _state = MutableStateFlow(CalendarUiState())
    val state = _state.asStateFlow()

    private var loadJob: Job? = null

    init {
        load()
        // Any change to the family calendar, from any device, refreshes the month.
        viewModelScope.launch { socket.events("calendar").collect { load() } }
    }

    fun showMonth(month: YearMonth) {
        _state.update { state ->
            val today = LocalDate.now()
            val selected = if (YearMonth.from(today) == month) today else month.atDay(1)
            state.copy(month = month, selected = selected)
        }
        load()
    }

    fun previousMonth() = showMonth(_state.value.month.minusMonths(1))
    fun nextMonth() = showMonth(_state.value.month.plusMonths(1))
    fun today() = showMonth(YearMonth.now())

    fun select(date: LocalDate) {
        if (YearMonth.from(date) != _state.value.month) {
            showMonth(YearMonth.from(date))
        }
        _state.update { it.copy(selected = date) }
    }

    fun load() {
        loadJob?.cancel()
        loadJob = viewModelScope.launch {
            val days = _state.value.gridDays
            val zone = ZoneId.systemDefault()
            val from = days.first().atStartOfDay(zone).toInstant()
            val to = days.last().plusDays(1).atStartOfDay(zone).toInstant()

            attempt { api.get<List<CalendarEvent>>("/calendar/events?from=$from&to=$to") }
                .onSuccess { events ->
                    val byDay = events
                        .flatMap { event -> event.dates.map { it to event } }
                        .groupBy({ it.first }, { it.second })
                        .mapValues { (_, list) -> list.sortedWith(compareBy({ !it.allDay }, { it.startsAt })) }
                    _state.update { it.copy(eventsByDay = byDay) }
                }
                .onFailure { e -> _state.update { it.copy(error = e.userMessage()) } }
        }
    }

    fun save(existing: CalendarEvent?, request: EventRequest) = write {
        if (existing == null) api.post<EventRequest, CalendarEvent>("/calendar/events", request)
        else api.patch<EventRequest, CalendarEvent>("/calendar/events/${existing.id}", request)
    }

    fun delete(event: CalendarEvent) = write { api.delete("/calendar/events/${event.id}") }

    fun errorShown() = _state.update { it.copy(error = null) }

    private fun write(block: suspend () -> Unit) {
        viewModelScope.launch {
            attempt { block() }.onFailure { e -> _state.update { it.copy(error = e.userMessage()) } }
            load()
        }
    }
}
