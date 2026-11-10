package app.portermills.data.socket

import app.portermills.BuildConfig
import app.portermills.data.api.AuthDataStore
import app.portermills.data.api.AuthState
import app.portermills.data.api.Session
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.collectLatest
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.filter
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.launch
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import java.util.concurrent.atomic.AtomicInteger
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Something that happened on one of the family's channel topics.
 * [feature] is "calendar", "lists" or "wishlists". [event] is the server's
 * event name, or [JOINED] each time the topic is (re)joined, which is the cue
 * to refetch in case anything was missed while offline.
 */
data class SocketEvent(val feature: String, val event: String, val payload: JsonObject) {
    companion object {
        const val JOINED = "joined"
    }
}

/**
 * Phoenix Channels client (V2 serializer) over an OkHttp WebSocket.
 *
 * Stays connected for as long as there is a session: joins the family's three
 * topics, sends heartbeats and reconnects after a drop. It only receives; all
 * writes go through the REST API.
 */
@Singleton
class PhoenixSocket @Inject constructor(private val auth: AuthDataStore) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val client = OkHttpClient()
    private val ref = AtomicInteger()
    private val _events = MutableSharedFlow<SocketEvent>(extraBufferCapacity = 64)

    init {
        scope.launch {
            auth.state
                .map { (it as? AuthState.SignedIn)?.session }
                .distinctUntilChanged()
                .collectLatest { session -> if (session != null) stayConnected(session) }
        }
    }

    fun events(feature: String): Flow<SocketEvent> = _events.filter { it.feature == feature }

    private suspend fun stayConnected(session: Session) {
        while (true) {
            val closed = CompletableDeferred<Unit>()
            val request = Request.Builder()
                .url("${BuildConfig.SOCKET_URL}?vsn=2.0.0&token=${session.token}")
                .build()
            val socket = client.newWebSocket(request, Listener(session, closed))

            try {
                coroutineScope {
                    val heartbeat = launch {
                        while (true) {
                            delay(HEARTBEAT_MS)
                            socket.send(frame("phoenix", "heartbeat"))
                        }
                    }
                    closed.await()
                    heartbeat.cancel()
                }
            } finally {
                // Also reached when the session ends and this coroutine is cancelled.
                socket.cancel()
            }
            delay(RECONNECT_MS)
        }
    }

    private fun frame(topic: String, event: String): String {
        val r = ref.incrementAndGet()
        return """["$r","$r","$topic","$event",{}]"""
    }

    private inner class Listener(
        private val session: Session,
        private val closed: CompletableDeferred<Unit>,
    ) : WebSocketListener() {
        override fun onOpen(webSocket: WebSocket, response: Response) {
            for (feature in FEATURES) {
                webSocket.send(frame("family:${session.familyId}:$feature", "phx_join"))
            }
        }

        override fun onMessage(webSocket: WebSocket, text: String) {
            // [join_ref, ref, topic, event, payload]
            val message = runCatching { Json.parseToJsonElement(text) as JsonArray }.getOrNull() ?: return
            if (message.size < 5) return
            val topic = message[2].jsonPrimitive.content
            val event = message[3].jsonPrimitive.content
            val payload = message[4] as? JsonObject ?: JsonObject(emptyMap())
            if (!topic.startsWith("family:")) return
            val feature = topic.substringAfterLast(':')

            when {
                event == "phx_reply" -> {
                    val joined = payload["status"]?.jsonPrimitive?.content == "ok" &&
                        payload["response"]?.jsonObject?.isEmpty() == true
                    if (joined) _events.tryEmit(SocketEvent(feature, SocketEvent.JOINED, payload))
                }
                event.startsWith("phx_") -> Unit
                else -> _events.tryEmit(SocketEvent(feature, event, payload))
            }
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            closed.complete(Unit)
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            closed.complete(Unit)
        }
    }

    private companion object {
        val FEATURES = listOf("calendar", "lists", "wishlists")
        const val HEARTBEAT_MS = 30_000L
        const val RECONNECT_MS = 3_000L
    }
}
