package app.portermills.features.lists

import androidx.lifecycle.SavedStateHandle
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.portermills.data.api.ApiClient
import app.portermills.data.api.ApiException
import app.portermills.data.api.attempt
import app.portermills.data.api.userMessage
import app.portermills.data.socket.PhoenixSocket
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ListDetailUiState(
    val list: FamilyListDetail? = null,
    /** The list was deleted (here or on another device); the screen should close. */
    val gone: Boolean = false,
    val message: String? = null,
) {
    val unchecked get() = list?.items.orEmpty().filter { !it.checked }
    val checked get() = list?.items.orEmpty().filter { it.checked }
}

/** One list and its items. */
@HiltViewModel
class ListDetailViewModel @Inject constructor(
    private val api: ApiClient,
    socket: PhoenixSocket,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    private val listId: String = checkNotNull(savedStateHandle["listId"])

    private val _state = MutableStateFlow(ListDetailUiState())
    val state = _state.asStateFlow()

    init {
        load()
        viewModelScope.launch { socket.events("lists").collect { load() } }
    }

    fun load() {
        viewModelScope.launch {
            attempt { api.get<FamilyListDetail>("/lists/$listId") }
                .onSuccess { list -> _state.update { it.copy(list = list) } }
                .onFailure { e ->
                    if (e is ApiException && e.code == 404) _state.update { it.copy(gone = true) }
                    else fail(e)
                }
        }
    }

    fun addItem(name: String) = write {
        api.post<ItemNameRequest, ListEntry>("/lists/$listId/items", ItemNameRequest(name))
    }

    fun toggle(item: ListEntry) {
        // Show the tick straight away; the reload after the write settles it.
        _state.update { state ->
            state.copy(list = state.list?.let { list ->
                list.copy(items = list.items.map { if (it.id == item.id) it.copy(checked = !item.checked) else it })
            })
        }
        write {
            api.patch<ItemCheckedRequest, ListEntry>(
                "/lists/$listId/items/${item.id}",
                ItemCheckedRequest(!item.checked),
            )
        }
    }

    fun renameItem(item: ListEntry, name: String) = write {
        api.patch<ItemNameRequest, ListEntry>("/lists/$listId/items/${item.id}", ItemNameRequest(name))
    }

    fun deleteItem(item: ListEntry) = write { api.delete("/lists/$listId/items/${item.id}") }

    fun renameList(name: String) = write {
        api.patch<RenameRequest, FamilyList>("/lists/$listId", RenameRequest(name))
    }

    fun deleteList() {
        viewModelScope.launch {
            attempt { api.delete("/lists/$listId") }
                .onSuccess { _state.update { it.copy(gone = true) } }
                .onFailure(::fail)
        }
    }

    fun saveAsTemplate(name: String) {
        viewModelScope.launch {
            attempt { api.post<SaveTemplateRequest, ListTemplate>("/list-templates", SaveTemplateRequest(name, listId)) }
                .onSuccess { _state.update { it.copy(message = "Saved \"$name\" as a template") } }
                .onFailure(::fail)
        }
    }

    fun messageShown() = _state.update { it.copy(message = null) }

    private fun write(block: suspend () -> Unit) {
        viewModelScope.launch {
            attempt { block() }.onFailure(::fail)
            load()
        }
    }

    private fun fail(e: Throwable) = _state.update { it.copy(message = e.userMessage()) }
}
