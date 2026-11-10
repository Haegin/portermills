package app.portermills.navigation

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.consumeWindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material.icons.filled.Checklist
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.navigation
import androidx.navigation.compose.rememberNavController
import app.portermills.data.api.AuthState
import app.portermills.features.auth.AuthViewModel
import app.portermills.features.auth.LoginScreen
import app.portermills.features.calendar.CalendarScreen
import app.portermills.features.lists.ListDetailScreen
import app.portermills.features.lists.ListsScreen
import app.portermills.features.wishlists.WishlistDetailScreen
import app.portermills.features.wishlists.WishlistsScreen

/** A bottom-bar tab; [route] is a nested graph so detail screens keep their tab selected. */
private enum class Tab(val route: String, val label: String, val icon: ImageVector) {
    Calendar("calendar", "Calendar", Icons.Default.CalendarMonth),
    Lists("lists", "Lists", Icons.Default.Checklist),
    Wishlists("wishlists", "Wishlists", Icons.Default.CardGiftcard),
}

@Composable
fun AppNavigation(authViewModel: AuthViewModel) {
    val auth by authViewModel.authState.collectAsStateWithLifecycle()

    when (auth) {
        AuthState.Loading -> Surface(Modifier.fillMaxSize()) {
            Box(contentAlignment = Alignment.Center) { CircularProgressIndicator() }
        }
        AuthState.SignedOut -> LoginScreen(authViewModel)
        is AuthState.SignedIn -> MainTabs()
    }
}

@Composable
private fun MainTabs() {
    val navController = rememberNavController()
    val currentEntry by navController.currentBackStackEntryAsState()

    Scaffold(
        // Each screen has its own top bar and handles the status-bar inset itself.
        contentWindowInsets = WindowInsets(0, 0, 0, 0),
        bottomBar = {
            NavigationBar {
                for (tab in Tab.entries) {
                    NavigationBarItem(
                        icon = { Icon(tab.icon, contentDescription = null) },
                        label = { Text(tab.label) },
                        selected = currentEntry?.destination?.hierarchy?.any { it.route == tab.route } == true,
                        onClick = {
                            navController.navigate(tab.route) {
                                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                    )
                }
            }
        },
    ) { padding ->
        NavHost(
            navController = navController,
            startDestination = Tab.Calendar.route,
            modifier = Modifier.padding(padding).consumeWindowInsets(padding),
        ) {
            navigation(startDestination = "calendar/month", route = Tab.Calendar.route) {
                composable("calendar/month") { CalendarScreen() }
            }
            navigation(startDestination = "lists/all", route = Tab.Lists.route) {
                composable("lists/all") {
                    ListsScreen(onOpenList = { id -> navController.navigate("lists/list/$id") })
                }
                composable("lists/list/{listId}") {
                    ListDetailScreen(onBack = { navController.popBackStack() })
                }
            }
            navigation(startDestination = "wishlists/all", route = Tab.Wishlists.route) {
                composable("wishlists/all") {
                    WishlistsScreen(onOpenWishlist = { id -> navController.navigate("wishlists/wishlist/$id") })
                }
                composable("wishlists/wishlist/{wishlistId}") {
                    WishlistDetailScreen(onBack = { navController.popBackStack() })
                }
            }
        }
    }
}
