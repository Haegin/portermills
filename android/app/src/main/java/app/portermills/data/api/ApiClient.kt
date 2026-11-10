package app.portermills.data.api

import app.portermills.BuildConfig
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.logging.HttpLoggingInterceptor
import javax.inject.Inject
import javax.inject.Singleton

val json = Json {
    ignoreUnknownKeys = true
    coerceInputValues = true
    encodeDefaults = true
}

@Singleton
class ApiClient @Inject constructor(private val authDataStore: AuthDataStore) {
    private val client = OkHttpClient.Builder()
        .addInterceptor { chain ->
            val token = authDataStore.tokenBlocking
            val req = chain.request().newBuilder().apply {
                header("Content-Type", "application/json")
                if (token != null) header("Authorization", "Bearer $token")
            }.build()
            chain.proceed(req)
        }
        .addInterceptor(HttpLoggingInterceptor().apply {
            level = if (BuildConfig.DEBUG) HttpLoggingInterceptor.Level.BODY
                    else HttpLoggingInterceptor.Level.NONE
        })
        .build()

    private val baseUrl = BuildConfig.API_BASE_URL
    private val mediaType = "application/json".toMediaType()

    suspend inline fun <reified T> get(path: String): T {
        val req = Request.Builder().url("$baseUrl$path").get().build()
        return execute(req)
    }

    suspend inline fun <reified B, reified T> post(path: String, body: B): T {
        val reqBody = json.encodeToString(body).toRequestBody(mediaType)
        val req = Request.Builder().url("$baseUrl$path").post(reqBody).build()
        return execute(req)
    }

    suspend inline fun <reified B, reified T> patch(path: String, body: B): T {
        val reqBody = json.encodeToString(body).toRequestBody(mediaType)
        val req = Request.Builder().url("$baseUrl$path").patch(reqBody).build()
        return execute(req)
    }

    suspend fun delete(path: String) {
        val req = Request.Builder().url("$baseUrl$path").delete().build()
        execute<Unit>(req)
    }

    suspend inline fun <reified T> execute(request: Request): T {
        val response = client.newCall(request).execute()
        if (!response.isSuccessful) throw ApiException(response.code)
        if (T::class == Unit::class) return Unit as T
        return json.decodeFromString(response.body!!.string())
    }
}

class ApiException(val code: Int) : Exception("HTTP $code")
