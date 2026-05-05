import {useQuery, useMutation, useQueryClient} from '@tanstack/react-query';
import {api} from '@/api/client';
import type {List, ListItem} from './types';

export function useLists() {
  return useQuery({
    queryKey: ['lists'],
    queryFn: () => api.get<List[]>('/lists'),
  });
}

export function useListItems(listId: string) {
  return useQuery({
    queryKey: ['lists', listId, 'items'],
    queryFn: () => api.get<ListItem[]>(`/lists/${listId}/items`),
  });
}

export function useToggleItem() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({listId, itemId, checked}: {listId: string; itemId: string; checked: boolean}) =>
      api.patch(`/lists/${listId}/items/${itemId}`, {checked}),
    onSuccess: (_data, {listId}) =>
      qc.invalidateQueries({queryKey: ['lists', listId, 'items']}),
  });
}

export function useAddItem() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({listId, name}: {listId: string; name: string}) =>
      api.post<ListItem>(`/lists/${listId}/items`, {name}),
    onSuccess: (_data, {listId}) =>
      qc.invalidateQueries({queryKey: ['lists', listId, 'items']}),
  });
}
