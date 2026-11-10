import Foundation

/// Everyone's wishlists.
@MainActor
final class WishlistsViewModel: LiveViewModel {
    @Published private(set) var wishlists: [Wishlist] = []

    init() { super.init(feature: "wishlists") }

    override func load() async {
        do {
            let all = try await api.get("/wishlists", as: [Wishlist].self)
            wishlists = all.filter(\.isMine) + all.filter { !$0.isMine }
        } catch {
            self.error = error.userMessage
        }
    }
}

/// One person's wishlist: editable by its owner, claimable by everyone else.
@MainActor
final class WishlistDetailViewModel: LiveViewModel {
    let wishlistId: String
    @Published private(set) var wishlist: Wishlist?
    /// The wishlist was hidden from the family; the screen should close.
    @Published private(set) var gone = false

    var isMine: Bool { wishlist?.isMine == true }

    init(wishlistId: String) {
        self.wishlistId = wishlistId
        // The server never sends claim events to a wishlist's owner.
        super.init(feature: "wishlists")
    }

    override func load() async {
        do {
            wishlist = try await api.get("/wishlists/\(wishlistId)", as: Wishlist.self)
        } catch where error.isNotFound {
            gone = true
        } catch {
            self.error = error.userMessage
        }
    }

    func save(_ existing: WishlistItem?, _ request: WishlistItemRequest) {
        perform {
            let base = "/wishlists/\(self.wishlistId)/items"
            if let existing {
                try await self.api.send("PATCH", "\(base)/\(existing.id)", body: request)
            } else {
                try await self.api.send("POST", base, body: request)
            }
        }
    }

    func delete(_ item: WishlistItem) {
        perform { try await self.api.send("DELETE", "/wishlists/\(self.wishlistId)/items/\(item.id)") }
    }

    func claim(_ item: WishlistItem) {
        perform { try await self.api.send("POST", "/wishlists/items/\(item.id)/claim") }
    }

    func release(_ item: WishlistItem) {
        perform { try await self.api.send("DELETE", "/wishlists/items/\(item.id)/claim") }
    }

    func setVisibleToFamily(_ visible: Bool) {
        perform {
            try await self.api.send("PATCH", "/wishlists/\(self.wishlistId)", body: VisibilityRequest(isVisibleToFamily: visible))
        }
    }
}
