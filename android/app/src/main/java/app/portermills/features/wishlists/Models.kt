package app.portermills.features.wishlists

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class WishlistOwner(val id: String, val name: String)

@Serializable
data class Wishlist(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("is_visible_to_family") val isVisibleToFamily: Boolean = true,
    @SerialName("is_mine") val isMine: Boolean = false,
    @SerialName("item_count") val itemCount: Int = 0,
    val user: WishlistOwner,
    /** Only present when a single wishlist is fetched. */
    val items: List<WishlistItem> = emptyList(),
) {
    val title: String get() = if (isMine) "My wishlist" else "${user.name}'s wishlist"
}

/**
 * The claim fields are absent from the server's response when the wishlist is
 * the caller's own, so the owner's app never learns what has been claimed.
 */
@Serializable
data class WishlistItem(
    val id: String,
    @SerialName("wishlist_id") val wishlistId: String,
    val name: String,
    val url: String? = null,
    val notes: String? = null,
    val price: String? = null,
    val priority: String = "medium",
    @SerialName("is_claimed") val isClaimed: Boolean = false,
    @SerialName("claimed_by_me") val claimedByMe: Boolean = false,
    @SerialName("claimed_by_name") val claimedByName: String? = null,
)

/** Body for creating or updating an item. An empty string clears a field. */
@Serializable
data class WishlistItemRequest(
    val name: String,
    val url: String,
    val notes: String,
    val price: String,
    val priority: String,
)

@Serializable
data class VisibilityRequest(@SerialName("is_visible_to_family") val isVisibleToFamily: Boolean)
