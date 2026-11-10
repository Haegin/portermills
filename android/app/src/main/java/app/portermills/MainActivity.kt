package app.portermills

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import app.portermills.features.auth.AuthViewModel
import app.portermills.navigation.AppNavigation
import app.portermills.ui.theme.PortermillsTheme
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private val authViewModel: AuthViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        // Only on a fresh launch: after a rotation the same intent is redelivered.
        if (savedInstanceState == null) handleMagicLink(intent)
        setContent {
            PortermillsTheme {
                AppNavigation(authViewModel)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleMagicLink(intent)
    }

    /** Completes sign-in when opened from a `portermills://auth?token=…` link. */
    private fun handleMagicLink(intent: Intent?) {
        val uri = intent?.data ?: return
        if (uri.scheme != "portermills" || uri.host != "auth") return
        val token = uri.getQueryParameter("token")?.takeIf { it.isNotBlank() } ?: return
        authViewModel.verifyToken(token)
    }
}
