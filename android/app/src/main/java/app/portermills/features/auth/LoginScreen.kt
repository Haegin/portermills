package app.portermills.features.auth

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle

@Composable
fun LoginScreen(viewModel: AuthViewModel) {
    val state by viewModel.login.collectAsStateWithLifecycle()
    var email by rememberSaveable { mutableStateOf("") }
    val canSend = email.contains('@') && !state.busy
    val send = { if (canSend) viewModel.requestMagicLink(email) }

    Scaffold { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .imePadding()
                .padding(horizontal = 32.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp, Alignment.CenterVertically),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text("Porter-Mills", style = MaterialTheme.typography.displaySmall)

            val sentTo = state.sentTo
            if (sentTo != null) {
                Text(
                    "Check your email",
                    style = MaterialTheme.typography.titleLarge,
                )
                Text(
                    "If $sentTo belongs to a family member, a sign-in link is on its way. Open it on this phone.",
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (state.busy) CircularProgressIndicator()
                TextButton(onClick = viewModel::startOver) { Text("Use a different email") }
            } else {
                Text(
                    "Sign in with your email and we'll send you a link.",
                    textAlign = TextAlign.Center,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                OutlinedTextField(
                    value = email,
                    onValueChange = { email = it },
                    label = { Text("Email") },
                    singleLine = true,
                    isError = state.error != null,
                    supportingText = state.error?.let { { Text(it) } },
                    keyboardOptions = KeyboardOptions(
                        keyboardType = KeyboardType.Email,
                        imeAction = ImeAction.Send,
                    ),
                    keyboardActions = KeyboardActions(onSend = { send() }),
                    modifier = Modifier.fillMaxWidth(),
                )
                Button(onClick = send, enabled = canSend, modifier = Modifier.fillMaxWidth()) {
                    if (state.busy) {
                        CircularProgressIndicator(
                            strokeWidth = 2.dp,
                            modifier = Modifier.padding(end = 8.dp).size(18.dp),
                        )
                    }
                    Text(if (state.busy) "Signing in…" else "Send sign-in link")
                }
            }
        }
    }
}
