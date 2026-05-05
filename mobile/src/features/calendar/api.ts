import {useQuery, useMutation, useQueryClient} from '@tanstack/react-query';
import {api} from '@/api/client';
import type {CalendarEvent} from './types';

export function useCalendarEvents(month: string) {
  return useQuery({
    queryKey: ['calendar', month],
    queryFn: () => api.get<CalendarEvent[]>(`/calendar/events?month=${month}`),
  });
}

export function useCreateEvent() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (data: Omit<CalendarEvent, 'id' | 'createdById'>) =>
      api.post<CalendarEvent>('/calendar/events', data),
    onSuccess: () => qc.invalidateQueries({queryKey: ['calendar']}),
  });
}

export function useDeleteEvent() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (id: string) => api.delete(`/calendar/events/${id}`),
    onSuccess: () => qc.invalidateQueries({queryKey: ['calendar']}),
  });
}
