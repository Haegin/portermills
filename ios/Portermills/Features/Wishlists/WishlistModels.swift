import Foundation

struct WishlistOwner: Decodable, Hashable {
    let id: String
    let name: String
}

struct Wishlist: Decodable, Identifiable, Hashable {
    let id: String
    let userId: String
    let isVisibleToFamily: Bool
    let isMine: Bool
    let itemCount: Int
    let user: WishlistOwner
    /// Only present when a single wishlist is fetched.
    let items: [WishlistItem]?

    var title: String { isMine ? "My wishlist" : "\(user.name)'s wishlist" }
}

/// The claim fields are absent from the server's response when the wishlist
/// is the caller's own, so the owner's app never learns what has been claimed.
struct WishlistItem: Decodable, Identifiable, Hashable {
    let id: String
    let wishlistId: String
    let name: String
    let url: String?
    let notes: String?
    let price: String?
    let priority: Priority
    let isClaimed: Bool?
    let claimedByMe: Bool?
    let claimedByName: String?

    enum Priority: String, Codable, CaseIterable {
        case low, medium, high

        var label: String {
            switch self {
            case .low: return "Nice to have"
            case .medium: return "Would like"
            case .high: return "Would love"
            }
        }
    }

    /// Only http(s) links are opened.
    var link: URL? {
        guard let url, url.hasPrefix("https://") || url.hasPrefix("http://") else { return nil }
        return URL(string: url)
    }
}

/// Body for creating or updating an item. An empty string clears a field.
struct WishlistItemRequest: Encodable {
    let name: String
    let url: String
    let notes: String
    let price: String
    let priority: WishlistItem.Priority
}

struct VisibilityRequest: Encodable {
    let isVisibleToFamily: Bool
}
