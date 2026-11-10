package app.portermills.features.wishlists

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material.icons.filled.VisibilityOff
import androidx.compose.material3.Icon
import androidx.compose.material3.ListItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.portermills.ui.components.AccountMenu
import app.portermills.ui.components.ErrorSnackbar

@Composable
fun WishlistsScreen(onOpenWishlist: (String) -> Unit, viewModel: WishlistsViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }

    ErrorSnackbar(state.error, snackbar, viewModel::errorShown)

    Scaffold(
        topBar = { TopAppBar(title = { Text("Wishlists") }, actions = { AccountMenu() }) },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        LazyColumn(Modifier.fillMaxSize().padding(padding)) {
            items(state.mine + state.others, key = { it.id }) { wishlist ->
                ListItem(
                    leadingContent = { Icon(Icons.Default.CardGiftcard, contentDescription = null) },
                    headlineContent = { Text(wishlist.title) },
                    supportingContent = {
                        Text(if (wishlist.itemCount == 1) "1 item" else "${wishlist.itemCount} items")
                    },
                    trailingContent = if (wishlist.isMine && !wishlist.isVisibleToFamily) {
                        { Icon(Icons.Default.VisibilityOff, "Hidden from the family") }
                    } else null,
                    modifier = Modifier.clickable { onOpenWishlist(wishlist.id) },
                )
            }
        }
    }
}
