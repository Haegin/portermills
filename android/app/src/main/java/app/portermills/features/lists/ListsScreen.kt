package app.portermills.features.lists

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ListItem
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.MenuAnchorType
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.portermills.ui.components.AccountMenu
import app.portermills.ui.components.ConfirmDialog
import app.portermills.ui.components.EmptyState
import app.portermills.ui.components.ErrorSnackbar
import app.portermills.ui.components.TextPromptDialog

@Composable
fun ListsScreen(onOpenList: (String) -> Unit, viewModel: ListsViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val snackbar = remember { SnackbarHostState() }
    var creating by remember { mutableStateOf(false) }
    var usingTemplate by remember { mutableStateOf<ListTemplate?>(null) }
    var renaming by remember { mutableStateOf<FamilyList?>(null) }
    var deleting by remember { mutableStateOf<FamilyList?>(null) }
    var deletingTemplate by remember { mutableStateOf<ListTemplate?>(null) }

    ErrorSnackbar(state.error, snackbar, viewModel::errorShown)

    Scaffold(
        topBar = { TopAppBar(title = { Text("Lists") }, actions = { AccountMenu() }) },
        floatingActionButton = {
            FloatingActionButton(onClick = { creating = true }) { Icon(Icons.Default.Add, "New list") }
        },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        if (state.loaded && state.lists.isEmpty() && state.templates.isEmpty()) {
            EmptyState("No lists yet", "Add a shopping list or a packing list with the + button.", Modifier.padding(padding))
        }
        LazyColumn(Modifier.fillMaxSize().padding(padding)) {
            listSection("Shopping", state.shopping, onOpenList, { renaming = it }, { deleting = it })
            listSection("Packing", state.packing, onOpenList, { renaming = it }, { deleting = it })

            if (state.templates.isNotEmpty()) {
                item(key = "templates-header") { SectionHeader("Packing templates") }
                items(state.templates, key = { "template-${it.id}" }) { template ->
                    ListItem(
                        headlineContent = { Text(template.name) },
                        supportingContent = { Text(itemCountLabel(template.items.size)) },
                        trailingContent = {
                            RowMenu(listOf("Delete template" to { deletingTemplate = template }))
                        },
                        modifier = Modifier.clickable { usingTemplate = template },
                    )
                }
            }
        }
    }

    if (creating) {
        NewListDialog(
            templates = state.templates,
            onDismiss = { creating = false },
            onCreate = { name, type, templateId ->
                viewModel.createList(name, type, templateId)
                creating = false
            },
        )
    }
    usingTemplate?.let { template ->
        TextPromptDialog(
            title = "New list from \"${template.name}\"",
            label = "List name",
            initial = template.name,
            confirmLabel = "Create",
            onDismiss = { usingTemplate = null },
            onConfirm = { name ->
                viewModel.createList(name, TYPE_PACKING, template.id)
                usingTemplate = null
            },
        )
    }
    renaming?.let { list ->
        TextPromptDialog(
            title = "Rename list",
            label = "Name",
            initial = list.name,
            onDismiss = { renaming = null },
            onConfirm = { name -> viewModel.renameList(list, name); renaming = null },
        )
    }
    deleting?.let { list ->
        ConfirmDialog(
            title = "Delete \"${list.name}\"?",
            message = "The list and everything on it will be removed for everyone.",
            onDismiss = { deleting = null },
            onConfirm = { viewModel.deleteList(list); deleting = null },
        )
    }
    deletingTemplate?.let { template ->
        ConfirmDialog(
            title = "Delete template \"${template.name}\"?",
            message = "Lists already made from it are kept.",
            onDismiss = { deletingTemplate = null },
            onConfirm = { viewModel.deleteTemplate(template); deletingTemplate = null },
        )
    }
}

private fun androidx.compose.foundation.lazy.LazyListScope.listSection(
    title: String,
    lists: List<FamilyList>,
    onOpen: (String) -> Unit,
    onRename: (FamilyList) -> Unit,
    onDelete: (FamilyList) -> Unit,
) {
    if (lists.isEmpty()) return
    item(key = "header-$title") { SectionHeader(title) }
    items(lists, key = { it.id }) { list ->
        ListItem(
            headlineContent = { Text(list.name) },
            supportingContent = {
                Text(
                    if (list.itemCount == 0) "Empty"
                    else "${list.checkedCount} of ${list.itemCount} ticked"
                )
            },
            trailingContent = {
                RowMenu(listOf("Rename" to { onRename(list) }, "Delete" to { onDelete(list) }))
            },
            modifier = Modifier.clickable { onOpen(list.id) },
        )
    }
}

@Composable
private fun SectionHeader(title: String) {
    Text(
        title,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(start = 16.dp, top = 20.dp, bottom = 4.dp),
    )
}

internal fun itemCountLabel(count: Int) = if (count == 1) "1 item" else "$count items"

/** A three-dot button opening a menu of [actions]. */
@Composable
internal fun RowMenu(actions: List<Pair<String, () -> Unit>>) {
    var open by remember { mutableStateOf(false) }
    Box {
        IconButton(onClick = { open = true }) { Icon(Icons.Default.MoreVert, "More") }
        DropdownMenu(expanded = open, onDismissRequest = { open = false }) {
            for ((label, action) in actions) {
                DropdownMenuItem(text = { Text(label) }, onClick = { open = false; action() })
            }
        }
    }
}

@Composable
private fun NewListDialog(
    templates: List<ListTemplate>,
    onDismiss: () -> Unit,
    onCreate: (name: String, type: String, templateId: String?) -> Unit,
) {
    var name by remember { mutableStateOf("") }
    var type by remember { mutableStateOf(TYPE_SHOPPING) }
    var template by remember { mutableStateOf<ListTemplate?>(null) }
    var templateMenuOpen by remember { mutableStateOf(false) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("New list") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    val types = listOf(TYPE_SHOPPING to "Shopping", TYPE_PACKING to "Packing")
                    types.forEachIndexed { index, (value, label) ->
                        SegmentedButton(
                            selected = type == value,
                            onClick = { type = value },
                            shape = SegmentedButtonDefaults.itemShape(index, types.size),
                        ) { Text(label) }
                    }
                }
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("Name") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                    modifier = Modifier.fillMaxWidth(),
                )
                if (type == TYPE_PACKING && templates.isNotEmpty()) {
                    ExposedDropdownMenuBox(
                        expanded = templateMenuOpen,
                        onExpandedChange = { templateMenuOpen = it },
                    ) {
                        OutlinedTextField(
                            value = template?.name ?: "None (start empty)",
                            onValueChange = {},
                            readOnly = true,
                            label = { Text("Template") },
                            trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(templateMenuOpen) },
                            modifier = Modifier.menuAnchor(MenuAnchorType.PrimaryNotEditable).fillMaxWidth(),
                        )
                        ExposedDropdownMenu(
                            expanded = templateMenuOpen,
                            onDismissRequest = { templateMenuOpen = false },
                        ) {
                            DropdownMenuItem(
                                text = { Text("None (start empty)") },
                                onClick = { template = null; templateMenuOpen = false },
                            )
                            for (option in templates) {
                                DropdownMenuItem(
                                    text = { Text("${option.name} · ${itemCountLabel(option.items.size)}") },
                                    onClick = {
                                        template = option
                                        if (name.isBlank()) name = option.name
                                        templateMenuOpen = false
                                    },
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = { onCreate(name.trim(), type, template?.id.takeIf { type == TYPE_PACKING }) },
                enabled = name.isNotBlank(),
            ) { Text("Create") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } },
    )
}
