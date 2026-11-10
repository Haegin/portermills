package app.portermills.features.lists

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController

@Composable
fun ListsScreen(vm: ListsViewModel = hiltViewModel()) {
    val navController = rememberNavController()
    val lists by vm.lists.collectAsState()

    NavHost(navController, startDestination = "lists") {
        composable("lists") {
            ListsListScreen(lists) { list -> navController.navigate("list/${list.id}") }
        }
        composable("list/{id}") { back ->
            val listId = back.arguments?.getString("id") ?: return@composable
            val list = lists.find { it.id == listId } ?: return@composable
            ListDetailScreen(list, vm)
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ListsListScreen(lists: List<ShoppingList>, onSelect: (ShoppingList) -> Unit) {
    Scaffold(topBar = { TopAppBar(title = { Text("Lists") }) }) { padding ->
        LazyColumn(contentPadding = PaddingValues(top = padding.calculateTopPadding())) {
            items(lists, key = { it.id }) { list ->
                ListItem(
                    headlineContent = { Text(list.name) },
                    supportingContent = { Text(list.type.replaceFirstChar { it.uppercase() }) },
                    modifier = Modifier.clickableWithRipple { onSelect(list) },
                )
                HorizontalDivider()
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ListDetailScreen(list: ShoppingList, vm: ListsViewModel) {
    val allItems by vm.items.collectAsState()
    val items = allItems[list.id] ?: emptyList()
    var newName by remember { mutableStateOf("") }

    LaunchedEffect(list.id) { vm.loadItems(list.id) }

    Scaffold(topBar = { TopAppBar(title = { Text(list.name) }) }) { padding ->
        Column(Modifier.padding(padding)) {
            LazyColumn(Modifier.weight(1f)) {
                items(items, key = { it.id }) { item ->
                    ListItem(
                        headlineContent = { Text(item.name) },
                        leadingContent = {
                            if (item.checked) Icon(Icons.Default.Check, null,
                                tint = MaterialTheme.colorScheme.primary)
                            else Spacer(Modifier.size(24.dp))
                        },
                        modifier = Modifier.clickableWithRipple { vm.toggleItem(list.id, item) },
                    )
                    HorizontalDivider()
                }
            }
            Row(Modifier.padding(16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = newName, onValueChange = { newName = it },
                    label = { Text("Add item…") }, modifier = Modifier.weight(1f), singleLine = true,
                )
                Button(
                    onClick = { vm.addItem(list.id, newName); newName = "" },
                    enabled = newName.isNotBlank(),
                ) { Text("Add") }
            }
        }
    }
}

private fun Modifier.clickableWithRipple(onClick: () -> Unit) =
    this.then(androidx.compose.foundation.clickable(onClick = onClick))
