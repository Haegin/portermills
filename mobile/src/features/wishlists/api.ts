import {useQuery, useMutation, useQueryClient} from '@tanstack/react-query';
import {api} from '@/api/client';
import type {Wishlist, WishlistItem} from './types';

export function useFamilyWishlists() {
  return useQuery({
    queryKey: ['wishlists'],
    queryFn: () => api.get<Wishlist[]>('/wishlists'),
  });
}

export function useWishlistItems(wishlistId: string) {
  return useQuery({
    queryKey: ['wishlists', wishlistId, 'items'],
    queryFn: () => api.get<WishlistItem[]>(`/wishlists/${wishlistId}/items`),
  });
}

export function useClaimItem() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: (itemId: string) =>
      api.post(`/wishlists/items/${itemId}/claim`, {}),
    onSuccess: () => qc.invalidateQueries({queryKey: ['wishlists']}),
  });
}

export function useAddWishlistItem() {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: ({wishlistId, item}: {wishlistId: string; item: Partial<WishlistItem>}) =>
      api.post<WishlistItem>(`/wishlists/${wishlistId}/items`, item),
    onSuccess: (_data, {wishlistId}) =>
      qc.invalidateQueries({queryKey: ['wishlists', wishlistId, 'items']}),
  });
}
