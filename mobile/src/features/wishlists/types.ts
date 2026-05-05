export interface Wishlist {
  id: string;
  userId: string;
  isVisibleToFamily: boolean;
}

export interface WishlistItem {
  id: string;
  wishlistId: string;
  name: string;
  url: string | null;
  notes: string | null;
  price: number | null;
  priority: 'low' | 'medium' | 'high';
  isClaimed: boolean; // true if someone else has claimed it (hidden who)
}
