package app.portermills.features.calendar

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.portermills.data.api.ApiClient
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import javax.inject.Inject

@HiltViewModel
class CalendarViewModel @Inject constructor(private val api: ApiClient) : ViewModel() {
    private val _events = MutableStateFlow<List<CalendarEvent>>(emptyList())
    val events = _events.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading = _isLoading.asStateFlow()

    private var displayedMonth = YearMonth.now()

    init { load() }

    fun load() {
        viewModelScope.launch {
            _isLoading.value = true
            try {
                val month = displayedMonth.format(DateTimeFormatter.ofPattern("yyyy-MM"))
                _events.value = api.get("/calendar/events?month=$month")
            } catch (_: Exception) {}
            _isLoading.value = false
        }
    }

    fun deleteEvent(event: CalendarEvent) {
        viewModelScope.launch {
            try {
                api.delete("/calendar/events/${event.id}")
                _events.value = _events.value.filter { it.id != event.id }
            } catch (_: Exception) {}
        }
    }
}
