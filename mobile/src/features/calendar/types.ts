export interface CalendarEvent {
  id: string;
  title: string;
  description: string | null;
  startsAt: string; // ISO 8601
  endsAt: string;
  allDay: boolean;
  recurrenceRule: string | null;
  createdById: string;
}
