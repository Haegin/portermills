package app.portermills.data.socket

import app.portermills.BuildConfig
import app.portermills.data.api.AuthDataStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class PhoenixSocket @Inject constructor(private val authDataStore: AuthDataStore) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val client = OkHttpClient()
    private var ws: WebSocket? = null
    private val handlers = mutableMapOf<String, (Any) -> Unit>()
    private var ref = 0

    fun connect() {
        scope.launch {
            val token = authDataStore.token.first() ?: return@launch
            val url = "${BuildConfig.SOCKET_URL}?token=$token"
            ws = client.newWebSocket(Request.Builder().url(url).build(), Listener())
        }
    }

    fun join(topic: String, onMessage: (Any) -> Unit) {
        handlers[topic] = onMessage
        push(topic, "phx_join", "{}")
    }

    fun leave(topic: String) {
        handlers.remove(topic)
        push(topic, "phx_leave", "{}")
    }

    fun push(topic: String, event: String, payload: String) {
        val msg = "[null,\"${++ref}\",\"$topic\",\"$event\",$payload]"
        ws?.send(msg)
    }

    private inner class Listener : WebSocketListener() {
        override fun onMessage(webSocket: WebSocket, text: String) {
            val arr = JSONArray(text)
            val topic = arr.getString(2)
            val event = arr.getString(3)
            if (event == "phx_reply") return
            handlers[topic]?.invoke(arr.get(4))
        }

        override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
            scope.launch {
                delay(3_000)
                connect()
            }
        }

        override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
            scope.launch {
                delay(3_000)
                connect()
            }
        }
    }
}
