package app.portermills.features.auth

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import app.portermills.data.api.ApiClient
import app.portermills.data.api.ApiException
import app.portermills.data.api.AuthDataStore
import app.portermills.data.api.Session
import app.portermills.data.api.attempt
import app.portermills.data.api.userMessage
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import javax.inject.Inject

data class LoginUiState(
    val busy: Boolean = false,
    /** The address a link was sent to, once one has been requested. */
    val sentTo: String? = null,
    val error: String? = null,
)

@HiltViewModel
class AuthViewModel @Inject constructor(
    private val api: ApiClient,
    private val authDataStore: AuthDataStore,
) : ViewModel() {

    val authState = authDataStore.state

    private val _login = MutableStateFlow(LoginUiState())
    val login = _login.asStateFlow()

    fun requestMagicLink(email: String) {
        val address = email.trim()
        _login.value = LoginUiState(busy = true)
        viewModelScope.launch {
            attempt { api.post<MagicLinkRequest, MagicLinkResponse>("/auth/magic-link", MagicLinkRequest(address)) }
                .onSuccess { _login.value = LoginUiState(sentTo = address) }
                .onFailure { e -> _login.value = LoginUiState(error = e.userMessage()) }
        }
    }

    /** Completes sign-in with the token from a magic link (see MainActivity). */
    fun verifyToken(token: String) {
        _login.update { it.copy(busy = true, error = null) }
        viewModelScope.launch {
            attempt { api.post<VerifyTokenRequest, AuthResponse>("/auth/verify", VerifyTokenRequest(token)) }
                .onSuccess { res ->
                    authDataStore.setSession(Session(res.token, res.user.id, res.user.name, res.user.familyId))
                    _login.value = LoginUiState()
                }
                .onFailure { e ->
                    val message =
                        if (e is ApiException && e.code == 401) "That sign-in link has expired or was already used. Request a new one."
                        else e.userMessage()
                    _login.value = LoginUiState(error = message)
                }
        }
    }

    fun startOver() {
        _login.value = LoginUiState()
    }

    fun signOut() {
        viewModelScope.launch { authDataStore.clear() }
    }
}
