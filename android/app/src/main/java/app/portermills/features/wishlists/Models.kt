package app.portermills.features.wishlists

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class Wishlist(
    val id: String,
    @SerialName("user_id") val userId: String,
    @SerialName("is_visible_to_family") val isVisibleToFamily: Boolean = true,
    val user: WishlistOwner? = null,
)

@Serializable
data class WishlistOwner(val id: String, val name: String)

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
)
