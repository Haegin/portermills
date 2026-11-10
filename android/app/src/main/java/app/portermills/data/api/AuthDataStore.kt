package app.portermills.data.api

import android.content.Context
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.runBlocking
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore by preferencesDataStore("auth")

@Singleton
class AuthDataStore @Inject constructor(@ApplicationContext private val context: Context) {
    private val TOKEN = stringPreferencesKey("token")
    private val USER_ID = stringPreferencesKey("user_id")
    private val USER_NAME = stringPreferencesKey("user_name")
    private val FAMILY_ID = stringPreferencesKey("family_id")

    val token: Flow<String?> = context.dataStore.data.map { it[TOKEN] }
    val userId: Flow<String?> = context.dataStore.data.map { it[USER_ID] }

    // Blocking read used only by OkHttp interceptor (runs off main thread)
    val tokenBlocking: String? get() = runBlocking { token.first() }

    suspend fun setAuth(token: String, userId: String, userName: String, familyId: String) {
        context.dataStore.edit {
            it[TOKEN] = token
            it[USER_ID] = userId
            it[USER_NAME] = userName
            it[FAMILY_ID] = familyId
        }
    }

    suspend fun clearAuth() {
        context.dataStore.edit { it.clear() }
    }
}
