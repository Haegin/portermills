package app.portermills.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.portermills.data.api.ApiClient
import app.portermills.data.api.AuthDataStore
import app.portermills.data.socket.PhoenixSocket
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import javax.inject.Inject

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val api: ApiClient,
    private val authDataStore: AuthDataStore,
    private val socket: PhoenixSocket,
) : ViewModel() {

    val isAuthenticated = authDataStore.token
        .map { it != null }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

    suspend fun requestMagicLink(email: String) {
        api.post<MagicLinkRequest, Unit>("/auth/magic-link", MagicLinkRequest(email))
    }

    suspend fun verifyToken(token: String): Boolean {
        return try {
            val res: AuthResponse = api.post("/auth/verify", VerifyTokenRequest(token))
            authDataStore.setAuth(res.token, res.user.id, res.user.name, res.user.familyId)
            socket.connect()
            true
        } catch (e: Exception) {
            false
        }
    }

    fun signOut() {
        viewModelScope.launch { authDataStore.clearAuth() }
    }
}
