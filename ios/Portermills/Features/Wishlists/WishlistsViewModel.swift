import Foundation

@MainActor
final class WishlistsViewModel: ObservableObject {
    @Published var wishlists: [Wishlist] = []
    @Published var itemsByWishlist: [String: [WishlistItem]] = [:]

    func load() async {
        wishlists = (try? await APIClient.shared.get("/wishlists")) ?? []
    }

    func loadItems(for wishlist: Wishlist) async {
        let items: [WishlistItem] = (try? await APIClient.shared.get(
            "/wishlists/\(wishlist.id)/items")) ?? []
        itemsByWishlist[wishlist.id] = items
    }

    func claimItem(_ item: WishlistItem) async {
        let _: EmptyResponse? = try? await APIClient.shared.post(
            "/wishlists/items/\(item.id)/claim", body: EmptyBody())
        refreshClaimed(item.id, claimed: true, wishlistId: item.wishlistId)
    }

    func unclaimItem(_ item: WishlistItem) async {
        try? await APIClient.shared.delete("/wishlists/items/\(item.id)/claim")
        refreshClaimed(item.id, claimed: false, wishlistId: item.wishlistId)
    }

    private func refreshClaimed(_ itemId: String, claimed: Bool, wishlistId: String) {
        guard let idx = itemsByWishlist[wishlistId]?.firstIndex(where: { $0.id == itemId }) else { return }
        let old = itemsByWishlist[wishlistId]![idx]
        itemsByWishlist[wishlistId]![idx] = WishlistItem(
            id: old.id, wishlistId: old.wishlistId, name: old.name,
            url: old.url, notes: old.notes, price: old.price,
            priority: old.priority, isClaimed: claimed)
    }
}

private struct EmptyBody: Encodable {}
private struct EmptyResponse: Decodable {}
