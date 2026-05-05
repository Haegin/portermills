package app.portermills.features.wishlists

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material.icons.outlined.CardGiftcard
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController

@Composable
fun WishlistsScreen(vm: WishlistsViewModel = hiltViewModel()) {
    val navController = rememberNavController()
    val wishlists by vm.wishlists.collectAsState()

    NavHost(navController, startDestination = "wishlists") {
        composable("wishlists") {
            WishlistListScreen(wishlists) { w -> navController.navigate("wishlist/${w.id}") }
        }
        composable("wishlist/{id}") { back ->
            val id = back.arguments?.getString("id") ?: return@composable
            val wishlist = wishlists.find { it.id == id } ?: return@composable
            WishlistDetailScreen(wishlist, vm)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WishlistListScreen(wishlists: List<Wishlist>, onSelect: (Wishlist) -> Unit) {
    Scaffold(topBar = { TopAppBar(title = { Text("Wishlists") }) }) { padding ->
        LazyColumn(contentPadding = PaddingValues(top = padding.calculateTopPadding())) {
            items(wishlists, key = { it.id }) { w ->
                ListItem(
                    headlineContent = { Text(w.user?.name ?: "Wishlist") },
                    modifier = Modifier.clickable { onSelect(w) },
                )
                HorizontalDivider()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun WishlistDetailScreen(wishlist: Wishlist, vm: WishlistsViewModel) {
    val allItems by vm.items.collectAsState()
    val currentUserId by vm.currentUserId.collectAsState()
    val items = allItems[wishlist.id] ?: emptyList()
    val isOwnWishlist = wishlist.userId == currentUserId

    LaunchedEffect(wishlist.id) { vm.loadItems(wishlist.id) }

    Scaffold(
        topBar = { TopAppBar(title = { Text("${wishlist.user?.name ?: "Wishlist"}") }) }
    ) { padding ->
        LazyColumn(contentPadding = PaddingValues(top = padding.calculateTopPadding())) {
            items(items, key = { it.id }) { item ->
                ListItem(
                    headlineContent = { Text(item.name) },
                    supportingContent = item.price?.let { { Text("$$it") } },
                    trailingContent = if (!isOwnWishlist) {
                        {
                            IconButton(onClick = { vm.toggleClaim(item) }) {
                                Icon(
                                    if (item.isClaimed) Icons.Filled.CardGiftcard
                                    else Icons.Outlined.CardGiftcard,
                                    contentDescription = if (item.isClaimed) "Unclaim" else "Claim",
                                    tint = if (item.isClaimed) MaterialTheme.colorScheme.primary
                                           else MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    } else null,
                )
                HorizontalDivider()
            }
        }
    }
}
