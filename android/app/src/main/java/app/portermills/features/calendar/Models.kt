package app.portermills.features.calendar

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class CalendarEvent(
    val id: String,
    val title: String,
    val description: String? = null,
    @SerialName("starts_at") val startsAt: String,
    @SerialName("ends_at") val endsAt: String,
    @SerialName("all_day") val allDay: Boolean = false,
    @SerialName("recurrence_rule") val recurrenceRule: String? = null,
    @SerialName("created_by_id") val createdById: String,
)

@Serializable
data class CreateEventRequest(
    val title: String,
    val description: String? = null,
    @SerialName("starts_at") val startsAt: String,
    @SerialName("ends_at") val endsAt: String,
    @SerialName("all_day") val allDay: Boolean = false,
)
