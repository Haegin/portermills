package app.portermills.navigation

import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Checklist
import androidx.compose.material.icons.filled.CardGiftcard
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import app.portermills.features.auth.AuthViewModel
import app.portermills.features.auth.LoginScreen
import app.portermills.features.calendar.CalendarScreen
import app.portermills.features.lists.ListsScreen
import app.portermills.features.wishlists.WishlistsScreen

sealed class Screen(val route: String, val label: String, val icon: ImageVector) {
    object Calendar : Screen("calendar", "Calendar", Icons.Default.CalendarMonth)
    object Lists : Screen("lists", "Lists", Icons.Default.Checklist)
    object Wishlists : Screen("wishlists", "Wishlists", Icons.Default.CardGiftcard)
}

private val mainScreens = listOf(Screen.Calendar, Screen.Lists, Screen.Wishlists)

@Composable
fun AppNavigation() {
    val authVm: AuthViewModel = hiltViewModel()
    val isAuthenticated by authVm.isAuthenticated.collectAsState()

    if (!isAuthenticated) {
        LoginScreen(viewModel = authVm)
        return
    }

    val navController = rememberNavController()

    Scaffold(
        bottomBar = {
            NavigationBar {
                val currentEntry by navController.currentBackStackEntryAsState()
                val currentDest = currentEntry?.destination
                mainScreens.forEach { screen ->
                    NavigationBarItem(
                        icon = { Icon(screen.icon, contentDescription = screen.label) },
                        label = { Text(screen.label) },
                        selected = currentDest?.hierarchy?.any { it.route == screen.route } == true,
                        onClick = {
                            navController.navigate(screen.route) {
                                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        }
                    )
                }
            }
        }
    ) { padding ->
        NavHost(navController, startDestination = Screen.Calendar.route) {
            composable(Screen.Calendar.route) { CalendarScreen() }
            composable(Screen.Lists.route) { ListsScreen() }
            composable(Screen.Wishlists.route) { WishlistsScreen() }
        }
    }
}
