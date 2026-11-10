package app.portermills.features.calendar

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZonedDateTime

@Serializable
data class CalendarEvent(
    val id: String,
    val title: String,
    val description: String? = null,
    @SerialName("starts_at") val startsAt: String,
    @SerialName("ends_at") val endsAt: String,
    @SerialName("all_day") val allDay: Boolean = false,
    @SerialName("recurrence_rule") val recurrenceRule: String? = null,
    @SerialName("created_by_id") val createdById: String? = null,
) {
    val start: ZonedDateTime get() = Instant.parse(startsAt).atZone(ZoneId.systemDefault())
    val end: ZonedDateTime get() = Instant.parse(endsAt).atZone(ZoneId.systemDefault())

    /** Every local date the event touches. */
    val dates: List<LocalDate>
        get() {
            val first = start.toLocalDate()
            // An event ending exactly at midnight doesn't count for the next day.
            val last = maxOf(first, (if (end > start) end.minusNanos(1) else end).toLocalDate())
            return generateSequence(first) { it.plusDays(1) }.takeWhile { !it.isAfter(last) }.toList()
        }
}

/** Body for creating or updating an event. Times are ISO 8601 instants. */
@Serializable
data class EventRequest(
    val title: String,
    val description: String,
    @SerialName("starts_at") val startsAt: String,
    @SerialName("ends_at") val endsAt: String,
    @SerialName("all_day") val allDay: Boolean,
)
