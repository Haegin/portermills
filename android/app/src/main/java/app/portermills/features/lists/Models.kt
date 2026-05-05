package app.portermills.features.lists

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class ShoppingList(
    val id: String,
    val type: String,
    val name: String,
    val archived: Boolean = false,
    @SerialName("family_id") val familyId: String,
)

@Serializable
data class ListItem(
    val id: String,
    @SerialName("list_id") val listId: String,
    val name: String,
    val checked: Boolean = false,
    val position: Int = 0,
    @SerialName("added_by_id") val addedById: String,
)

@Serializable
data class AddItemRequest(val name: String)

@Serializable
data class ToggleItemRequest(val checked: Boolean)
