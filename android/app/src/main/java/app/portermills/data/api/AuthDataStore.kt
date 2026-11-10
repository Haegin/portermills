package app.portermills.data.api

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore by preferencesDataStore("auth")

data class Session(
    val token: String,
    val userId: String,
    val userName: String,
    val familyId: String,
)

sealed interface AuthState {
    /** The stored session hasn't been read from disk yet. */
    data object Loading : AuthState
    data object SignedOut : AuthState
    data class SignedIn(val session: Session) : AuthState
}

@Singleton
class AuthDataStore @Inject constructor(@ApplicationContext private val context: Context) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    val state: StateFlow<AuthState> = context.dataStore.data
        .map { prefs ->
            val token = prefs[TOKEN]
            val userId = prefs[USER_ID]
            val familyId = prefs[FAMILY_ID]
            if (token != null && userId != null && familyId != null) {
                AuthState.SignedIn(Session(token, userId, prefs[USER_NAME].orEmpty(), familyId))
            } else {
                AuthState.SignedOut
            }
        }
        .stateIn(scope, SharingStarted.Eagerly, AuthState.Loading)

    /** The current session, held in memory so callers never block on disk. */
    val session: Session? get() = (state.value as? AuthState.SignedIn)?.session

    suspend fun setSession(session: Session) {
        context.dataStore.edit {
            it[TOKEN] = session.token
            it[USER_ID] = session.userId
            it[USER_NAME] = session.userName
            it[FAMILY_ID] = session.familyId
        }
    }

    suspend fun clear() {
        context.dataStore.edit { it.clear() }
    }

    private companion object {
        val TOKEN = stringPreferencesKey("token")
        val USER_ID = stringPreferencesKey("user_id")
        val USER_NAME = stringPreferencesKey("user_name")
        val FAMILY_ID = stringPreferencesKey("family_id")
    }
}
