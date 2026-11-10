package app.portermills.features.wishlists

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

data class WishlistDetailUiState(
    val wishlist: Wishlist? = null,
    /** The wishlist was hidden from the family; the screen should close. */
    val gone: Boolean = false,
    val error: String? = null,
)

/** One person's wishlist: editable by its owner, claimable by everyone else. */
@HiltViewModel
class WishlistDetailViewModel @Inject constructor(
    private val api: ApiClient,
    socket: PhoenixSocket,
    savedStateHandle: SavedStateHandle,
) : ViewModel() {
    private val wishlistId: String = checkNotNull(savedStateHandle["wishlistId"])

    private val _state = MutableStateFlow(WishlistDetailUiState())
    val state = _state.asStateFlow()

    init {
        load()
        // The server never sends claim events to a wishlist's owner.
        viewModelScope.launch { socket.events("wishlists").collect { load() } }
    }

    fun load() {
        viewModelScope.launch {
            attempt { api.get<Wishlist>("/wishlists/$wishlistId") }
                .onSuccess { wishlist -> _state.update { it.copy(wishlist = wishlist) } }
                .onFailure { e ->
                    if (e is ApiException && e.code == 404) _state.update { it.copy(gone = true) }
                    else fail(e)
                }
        }
    }

    fun saveItem(existing: WishlistItem?, request: WishlistItemRequest) = write {
        val base = "/wishlists/$wishlistId/items"
        if (existing == null) api.post<WishlistItemRequest, WishlistItem>(base, request)
        else api.patch<WishlistItemRequest, WishlistItem>("$base/${existing.id}", request)
    }

    fun deleteItem(item: WishlistItem) = write { api.delete("/wishlists/$wishlistId/items/${item.id}") }

    fun claim(item: WishlistItem) = write { api.post<WishlistItem>("/wishlists/items/${item.id}/claim") }

    fun unclaim(item: WishlistItem) = write {
        api.deleteReturning<WishlistItem>("/wishlists/items/${item.id}/claim")
    }

    fun setVisibleToFamily(visible: Boolean) = write {
        api.patch<VisibilityRequest, Wishlist>("/wishlists/$wishlistId", VisibilityRequest(visible))
    }

    fun errorShown() = _state.update { it.copy(error = null) }

    private fun write(block: suspend () -> Unit) {
        viewModelScope.launch {
            attempt { block() }.onFailure(::fail)
            load()
        }
    }

    private fun fail(e: Throwable) = _state.update { it.copy(error = e.userMessage()) }
}
