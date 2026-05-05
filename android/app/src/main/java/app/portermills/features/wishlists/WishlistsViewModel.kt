package app.portermills.features.wishlists

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.portermills.data.api.ApiClient
import app.portermills.data.api.AuthDataStore
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class WishlistsViewModel @Inject constructor(
    private val api: ApiClient,
    private val authDataStore: AuthDataStore,
) : ViewModel() {
    private val _wishlists = MutableStateFlow<List<Wishlist>>(emptyList())
    val wishlists = _wishlists.asStateFlow()

    private val _items = MutableStateFlow<Map<String, List<WishlistItem>>>(emptyMap())
    val items = _items.asStateFlow()

    private val _currentUserId = MutableStateFlow<String?>(null)
    val currentUserId = _currentUserId.asStateFlow()

    init {
        viewModelScope.launch {
            _currentUserId.value = authDataStore.userId.first()
            _wishlists.value = runCatching { api.get("/wishlists") }.getOrDefault(emptyList())
        }
    }

    fun loadItems(wishlistId: String) {
        viewModelScope.launch {
            val fetched: List<WishlistItem> =
                runCatching { api.get("/wishlists/$wishlistId/items") }.getOrDefault(emptyList())
            _items.value = _items.value + (wishlistId to fetched)
        }
    }

    fun toggleClaim(item: WishlistItem) {
        viewModelScope.launch {
            try {
                if (item.isClaimed) api.delete("/wishlists/items/${item.id}/claim")
                else api.post<Unit, Unit>("/wishlists/items/${item.id}/claim", Unit)
                val updated = item.copy(isClaimed = !item.isClaimed)
                _items.value = _items.value + (item.wishlistId to
                    _items.value[item.wishlistId].orEmpty().map { if (it.id == item.id) updated else it })
            } catch (_: Exception) {}
        }
    }
}
