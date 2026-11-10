package app.portermills.features.wishlists

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

data class WishlistsUiState(
    val wishlists: List<Wishlist> = emptyList(),
    val error: String? = null,
) {
    val mine get() = wishlists.filter { it.isMine }
    val others get() = wishlists.filter { !it.isMine }
}

/** Everyone's wishlists. */
@HiltViewModel
class WishlistsViewModel @Inject constructor(
    private val api: ApiClient,
    socket: PhoenixSocket,
) : ViewModel() {
    private val _state = MutableStateFlow(WishlistsUiState())
    val state = _state.asStateFlow()

    init {
        load()
        viewModelScope.launch { socket.events("wishlists").collect { load() } }
    }

    fun load() {
        viewModelScope.launch {
            attempt { api.get<List<Wishlist>>("/wishlists") }
                .onSuccess { wishlists -> _state.update { it.copy(wishlists = wishlists) } }
                .onFailure { e -> _state.update { it.copy(error = e.userMessage()) } }
        }
    }

    fun errorShown() = _state.update { it.copy(error = null) }
}
