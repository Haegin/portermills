package app.portermills.features.lists

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.portermills.data.api.ApiClient
import app.portermills.data.api.attempt
import app.portermills.data.api.userMessage
import app.portermills.data.socket.PhoenixSocket
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class ListsUiState(
    val lists: List<FamilyList> = emptyList(),
    val templates: List<ListTemplate> = emptyList(),
    val loaded: Boolean = false,
    val error: String? = null,
) {
    val shopping get() = lists.filter { it.type == TYPE_SHOPPING }
    val packing get() = lists.filter { it.type == TYPE_PACKING }
}

/** The overview of all lists and packing-list templates. */
@HiltViewModel
class ListsViewModel @Inject constructor(
    private val api: ApiClient,
    socket: PhoenixSocket,
) : ViewModel() {
    private val _state = MutableStateFlow(ListsUiState())
    val state = _state.asStateFlow()

    init {
        load()
        // Lists, items (for the counts) and templates all arrive on the lists topic.
        viewModelScope.launch { socket.events("lists").collect { load() } }
    }

    fun load() {
        viewModelScope.launch {
            attempt { api.get<List<FamilyList>>("/lists") to api.get<List<ListTemplate>>("/list-templates") }
                .onSuccess { (lists, templates) ->
                    _state.update { it.copy(lists = lists, templates = templates, loaded = true) }
                }
                .onFailure(::fail)
        }
    }

    fun createList(name: String, type: String, templateId: String? = null) = write {
        api.post<CreateListRequest, FamilyList>("/lists", CreateListRequest(name, type, templateId))
    }

    fun renameList(list: FamilyList, name: String) = write {
        api.patch<RenameRequest, FamilyList>("/lists/${list.id}", RenameRequest(name))
    }

    fun deleteList(list: FamilyList) = write { api.delete("/lists/${list.id}") }

    fun deleteTemplate(template: ListTemplate) = write { api.delete("/list-templates/${template.id}") }

    fun errorShown() = _state.update { it.copy(error = null) }

    private fun write(block: suspend () -> Unit) {
        viewModelScope.launch {
            attempt { block() }.onFailure(::fail)
            load()
        }
    }

    private fun fail(e: Throwable) = _state.update { it.copy(error = e.userMessage()) }
}
