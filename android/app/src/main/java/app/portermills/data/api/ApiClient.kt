package app.portermills.data.api

import app.portermills.BuildConfig
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.logging.HttpLoggingInterceptor
import javax.inject.Inject
import javax.inject.Singleton

class ApiException(val code: Int, val body: String) : Exception("HTTP $code")

@Singleton
class ApiClient @Inject constructor(private val auth: AuthDataStore) {
    /** Public because the inline helpers below are inlined into callers. */
    val json = Json {
        ignoreUnknownKeys = true
        coerceInputValues = true
        encodeDefaults = true
        explicitNulls = false
    }

    private val client = OkHttpClient.Builder()
        .addInterceptor(HttpLoggingInterceptor().apply {
            level = if (BuildConfig.DEBUG) HttpLoggingInterceptor.Level.BASIC
            else HttpLoggingInterceptor.Level.NONE
        })
        .build()

    private val mediaType = "application/json".toMediaType()

    /**
     * Performs a request off the caller's thread and returns the response body.
     * Throws [ApiException] for a non-2xx status and IOException when the
     * server can't be reached. A 401 ends the session.
     */
    suspend fun request(method: String, path: String, body: String? = null): String =
        withContext(Dispatchers.IO) {
            val requestBody = body?.toRequestBody(mediaType)
                ?: if (method == "POST" || method == "PATCH") "{}".toRequestBody(mediaType) else null

            val request = Request.Builder()
                .url(BuildConfig.API_BASE_URL + path)
                .method(method, requestBody)
                .apply { auth.session?.let { header("Authorization", "Bearer ${it.token}") } }
                .build()

            client.newCall(request).execute().use { response ->
                val text = response.body?.string().orEmpty()
                if (response.code == 401 && auth.session != null) auth.clear()
                if (!response.isSuccessful) throw ApiException(response.code, text)
                text
            }
        }

    suspend inline fun <reified T> get(path: String): T =
        json.decodeFromString(request("GET", path))

    suspend inline fun <reified B, reified T> post(path: String, body: B): T =
        json.decodeFromString(request("POST", path, json.encodeToString(body)))

    suspend inline fun <reified T> post(path: String): T =
        json.decodeFromString(request("POST", path))

    suspend inline fun <reified B, reified T> patch(path: String, body: B): T =
        json.decodeFromString(request("PATCH", path, json.encodeToString(body)))

    suspend inline fun <reified T> deleteReturning(path: String): T =
        json.decodeFromString(request("DELETE", path))

    suspend fun delete(path: String) {
        request("DELETE", path)
    }
}

/** Runs [block], turning failures (but not cancellation) into a [Result]. */
suspend fun <T> attempt(block: suspend () -> T): Result<T> =
    try {
        Result.success(block())
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        Result.failure(e)
    }

/** A short message for showing a failed request to the user. */
fun Throwable.userMessage(): String = when (this) {
    is ApiException -> when (code) {
        401 -> "You've been signed out."
        403 -> "You're not allowed to do that."
        404 -> "That no longer exists."
        409 -> "Someone else got there first."
        422 -> "That couldn't be saved. Check the details and try again."
        else -> "The server returned an error ($code)."
    }
    is java.io.IOException -> "Can't reach the server."
    else -> "Something went wrong."
}
