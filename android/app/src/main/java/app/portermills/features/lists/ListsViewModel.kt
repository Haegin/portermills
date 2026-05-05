package app.portermills.features.lists

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.portermills.data.api.ApiClient
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class ListsViewModel @Inject constructor(private val api: ApiClient) : ViewModel() {
    private val _lists = MutableStateFlow<List<ShoppingList>>(emptyList())
    val lists = _lists.asStateFlow()

    private val _items = MutableStateFlow<Map<String, List<ListItem>>>(emptyMap())
    val items = _items.asStateFlow()

    init { load() }

    fun load() {
        viewModelScope.launch {
            _lists.value = runCatching { api.get<List<ShoppingList>>("/lists") }.getOrDefault(emptyList())
        }
    }

    fun loadItems(listId: String) {
        viewModelScope.launch {
            val fetched: List<ListItem> = runCatching { api.get("/lists/$listId/items") }.getOrDefault(emptyList())
            _items.value = _items.value + (listId to fetched)
        }
    }

    fun addItem(listId: String, name: String) {
        viewModelScope.launch {
            val item: ListItem = runCatching {
                api.post("/lists/$listId/items", AddItemRequest(name))
            }.getOrReturn { return@launch }
            _items.value = _items.value + (listId to (_items.value[listId].orEmpty() + item))
        }
    }

    fun toggleItem(listId: String, item: ListItem) {
        viewModelScope.launch {
            val updated: ListItem = runCatching {
                api.patch("/lists/$listId/items/${item.id}", ToggleItemRequest(!item.checked))
            }.getOrReturn { return@launch }
            _items.value = _items.value + (listId to _items.value[listId].orEmpty().map {
                if (it.id == updated.id) updated else it
            })
        }
    }
}

private inline fun <T> Result<T>.getOrReturn(block: () -> T): T = getOrElse { block() }
