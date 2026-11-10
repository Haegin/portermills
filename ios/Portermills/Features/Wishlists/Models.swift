import Foundation

struct Wishlist: Identifiable, Codable {
    let id: String
    let userId: String
    let isVisibleToFamily: Bool
    let user: WishlistOwner?
}

struct WishlistOwner: Codable {
    let id: String
    let name: String
}

struct WishlistItem: Identifiable, Codable {
    let id: String
    let wishlistId: String
    let name: String
    let url: String?
    let notes: String?
    let price: Decimal?
    let priority: Priority
    let isClaimed: Bool

    enum Priority: String, Codable { case low, medium, high }
}
