package app.portermills.features.lists

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.portermills.ui.components.ConfirmDialog
import app.portermills.ui.components.EmptyState
import app.portermills.ui.components.ErrorSnackbar
import app.portermills.ui.components.TextPromptDialog

@Composable
fun ListDetailScreen(onBack: () -> Unit, viewModel: ListDetailViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val list = state.list
    val snackbar = remember { SnackbarHostState() }
    var newItem by rememberSaveable { mutableStateOf("") }
    var renamingList by remember { mutableStateOf(false) }
    var deletingList by remember { mutableStateOf(false) }
    var savingTemplate by remember { mutableStateOf(false) }
    var renamingItem by remember { mutableStateOf<ListEntry?>(null) }

    LaunchedEffect(state.gone) { if (state.gone) onBack() }
    ErrorSnackbar(state.message, snackbar, viewModel::messageShown)

    val submitItem = {
        if (newItem.isNotBlank()) {
            viewModel.addItem(newItem.trim())
            newItem = ""
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(list?.name.orEmpty()) },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") }
                },
                actions = {
                    RowMenu(buildList {
                        add("Rename list" to { renamingList = true })
                        if (list?.type == TYPE_PACKING) add("Save as template" to { savingTemplate = true })
                        add("Delete list" to { deletingList = true })
                    })
                },
            )
        },
        bottomBar = {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth().imePadding().padding(start = 16.dp, end = 8.dp, bottom = 8.dp),
            ) {
                OutlinedTextField(
                    value = newItem,
                    onValueChange = { newItem = it },
                    placeholder = { Text("Add an item") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(
                        capitalization = KeyboardCapitalization.Sentences,
                        imeAction = ImeAction.Done,
                    ),
                    keyboardActions = KeyboardActions(onDone = { submitItem() }),
                    modifier = Modifier.weight(1f),
                )
                IconButton(onClick = submitItem, enabled = newItem.isNotBlank()) {
                    Icon(Icons.Default.Add, "Add item")
                }
            }
        },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        if (list != null && list.items.isEmpty()) {
            EmptyState("Nothing here yet", "Add the first item below.", Modifier.padding(padding))
        }
        LazyColumn(Modifier.fillMaxSize().padding(padding)) {
            items(state.unchecked, key = { it.id }) { item ->
                ItemRow(item, viewModel::toggle, { renamingItem = item }, viewModel::deleteItem)
            }
            if (state.checked.isNotEmpty()) {
                item(key = "ticked-header") {
                    Text(
                        "Ticked",
                        style = MaterialTheme.typography.titleSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(start = 16.dp, top = 16.dp, bottom = 4.dp),
                    )
                }
            }
            items(state.checked, key = { it.id }) { item ->
                ItemRow(item, viewModel::toggle, { renamingItem = item }, viewModel::deleteItem)
            }
        }
    }

    if (renamingList && list != null) {
        TextPromptDialog(
            title = "Rename list",
            label = "Name",
            initial = list.name,
            onDismiss = { renamingList = false },
            onConfirm = { name -> viewModel.renameList(name); renamingList = false },
        )
    }
    if (savingTemplate && list != null) {
        TextPromptDialog(
            title = "Save as template",
            label = "Template name",
            initial = list.name,
            onDismiss = { savingTemplate = false },
            onConfirm = { name -> viewModel.saveAsTemplate(name); savingTemplate = false },
        )
    }
    if (deletingList && list != null) {
        ConfirmDialog(
            title = "Delete \"${list.name}\"?",
            message = "The list and everything on it will be removed for everyone.",
            onDismiss = { deletingList = false },
            onConfirm = { deletingList = false; viewModel.deleteList() },
        )
    }
    renamingItem?.let { item ->
        TextPromptDialog(
            title = "Edit item",
            label = "Name",
            initial = item.name,
            onDismiss = { renamingItem = null },
            onConfirm = { name -> viewModel.renameItem(item, name); renamingItem = null },
        )
    }
}

@Composable
private fun ItemRow(
    item: ListEntry,
    onToggle: (ListEntry) -> Unit,
    onEdit: () -> Unit,
    onDelete: (ListEntry) -> Unit,
) {
    ListItem(
        leadingContent = { Checkbox(checked = item.checked, onCheckedChange = { onToggle(item) }) },
        headlineContent = {
            Text(
                item.name,
                textDecoration = if (item.checked) TextDecoration.LineThrough else null,
                color = if (item.checked) MaterialTheme.colorScheme.onSurfaceVariant else MaterialTheme.colorScheme.onSurface,
            )
        },
        trailingContent = { RowMenu(listOf("Edit" to onEdit, "Delete" to { onDelete(item) })) },
        modifier = Modifier.clickable { onToggle(item) },
    )
}
