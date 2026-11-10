package app.portermills.features.lists

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

const val TYPE_SHOPPING = "shopping"
const val TYPE_PACKING = "packing"

/** A shopping or packing list. Named FamilyList to stay clear of kotlin.collections.List. */
@Serializable
data class FamilyList(
    val id: String,
    val type: String,
    val name: String,
    val archived: Boolean = false,
    @SerialName("item_count") val itemCount: Int = 0,
    @SerialName("checked_count") val checkedCount: Int = 0,
)

@Serializable
data class ListEntry(
    val id: String,
    @SerialName("list_id") val listId: String,
    val name: String,
    val checked: Boolean = false,
    val position: Int = 0,
)

@Serializable
data class FamilyListDetail(
    val id: String,
    val type: String,
    val name: String,
    val items: List<ListEntry> = emptyList(),
)

/** A reusable packing list. */
@Serializable
data class ListTemplate(
    val id: String,
    val name: String,
    val items: List<TemplateItem> = emptyList(),
)

@Serializable
data class TemplateItem(val id: String, val name: String)

@Serializable
data class CreateListRequest(
    val name: String,
    val type: String,
    @SerialName("template_id") val templateId: String? = null,
)

@Serializable
data class RenameRequest(val name: String)

@Serializable
data class ItemNameRequest(val name: String)

@Serializable
data class ItemCheckedRequest(val checked: Boolean)

@Serializable
data class SaveTemplateRequest(
    val name: String,
    @SerialName("from_list_id") val fromListId: String,
)
