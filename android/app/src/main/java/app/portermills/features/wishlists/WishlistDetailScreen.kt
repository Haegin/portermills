package app.portermills.features.wishlists

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SegmentedButton
import androidx.compose.material3.SegmentedButtonDefaults
import androidx.compose.material3.SingleChoiceSegmentedButtonRow
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.portermills.ui.components.ConfirmDialog
import app.portermills.ui.components.EmptyState
import app.portermills.ui.components.ErrorSnackbar

/** What the item editor is open on. */
private sealed interface Editing {
    data object New : Editing
    data class Existing(val item: WishlistItem) : Editing
}

@Composable
fun WishlistDetailScreen(onBack: () -> Unit, viewModel: WishlistDetailViewModel = hiltViewModel()) {
    val state by viewModel.state.collectAsStateWithLifecycle()
    val wishlist = state.wishlist
    val isMine = wishlist?.isMine == true
    val snackbar = remember { SnackbarHostState() }
    var editing by remember { mutableStateOf<Editing?>(null) }

    LaunchedEffect(state.gone) { if (state.gone) onBack() }
    ErrorSnackbar(state.error, snackbar, viewModel::errorShown)

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(wishlist?.title.orEmpty()) },
                navigationIcon = {
                    IconButton(onClick = onBack) { Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back") }
                },
            )
        },
        floatingActionButton = {
            if (isMine) {
                FloatingActionButton(onClick = { editing = Editing.New }) { Icon(Icons.Default.Add, "Add item") }
            }
        },
        snackbarHost = { SnackbarHost(snackbar) },
    ) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            if (wishlist != null && isMine) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
                ) {
                    Text("Visible to the family", modifier = Modifier.weight(1f))
                    Switch(
                        checked = wishlist.isVisibleToFamily,
                        onCheckedChange = viewModel::setVisibleToFamily,
                    )
                }
                HorizontalDivider()
            }
            if (wishlist != null && wishlist.items.isEmpty()) {
                EmptyState(
                    "Nothing here yet",
                    if (isMine) "Add things you'd like with the + button." else "${wishlist.user.name} hasn't added anything.",
                )
            }
            LazyColumn(Modifier.fillMaxSize()) {
                items(wishlist?.items.orEmpty(), key = { it.id }) { item ->
                    WishlistItemRow(
                        item = item,
                        isMine = isMine,
                        onEdit = { editing = Editing.Existing(item) },
                        onClaim = { viewModel.claim(item) },
                        onUnclaim = { viewModel.unclaim(item) },
                    )
                    HorizontalDivider()
                }
            }
        }
    }

    when (val target = editing) {
        null -> Unit
        Editing.New -> ItemEditor(
            item = null,
            onDismiss = { editing = null },
            onSave = { request -> viewModel.saveItem(null, request); editing = null },
            onDelete = {},
        )
        is Editing.Existing -> ItemEditor(
            item = target.item,
            onDismiss = { editing = null },
            onSave = { request -> viewModel.saveItem(target.item, request); editing = null },
            onDelete = { viewModel.deleteItem(target.item); editing = null },
        )
    }
}

@Composable
private fun WishlistItemRow(
    item: WishlistItem,
    isMine: Boolean,
    onEdit: () -> Unit,
    onClaim: () -> Unit,
    onUnclaim: () -> Unit,
) {
    val context = LocalContext.current
    val link = item.url?.takeIf { it.startsWith("http://") || it.startsWith("https://") }

    Column(
        verticalArrangement = Arrangement.spacedBy(4.dp),
        modifier = Modifier
            .fillMaxWidth()
            .then(if (isMine) Modifier.clickable(onClick = onEdit) else Modifier)
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(item.name, style = MaterialTheme.typography.titleMedium, modifier = Modifier.weight(1f))
            item.price?.let { Text("£$it", style = MaterialTheme.typography.titleMedium) }
        }
        val details = listOfNotNull(
            when (item.priority) {
                "high" -> "Would love"
                "low" -> "Nice to have"
                else -> null
            },
            item.notes?.takeIf { it.isNotBlank() },
        )
        if (details.isNotEmpty()) {
            Text(
                details.joinToString(" · "),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            if (link != null) {
                TextButton(
                    onClick = {
                        runCatching { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(link))) }
                    },
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp),
                ) { Text("View online") }
            }
            Spacer(Modifier.weight(1f))
            // The owner sees no claim controls and no claim state.
            if (!isMine) {
                when {
                    item.claimedByMe -> OutlinedButton(onClick = onUnclaim) { Text("Claimed by you · Release") }
                    item.isClaimed -> Text(
                        "Claimed by ${item.claimedByName ?: "someone"}",
                        style = MaterialTheme.typography.labelLarge,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                    else -> Button(onClick = onClaim) { Text("Claim") }
                }
            }
        }
    }
}

@Composable
private fun ItemEditor(
    item: WishlistItem?,
    onDismiss: () -> Unit,
    onSave: (WishlistItemRequest) -> Unit,
    onDelete: () -> Unit,
) {
    var name by remember { mutableStateOf(item?.name.orEmpty()) }
    var url by remember { mutableStateOf(item?.url.orEmpty()) }
    var notes by remember { mutableStateOf(item?.notes.orEmpty()) }
    var price by remember { mutableStateOf(item?.price.orEmpty()) }
    var priority by remember { mutableStateOf(item?.priority ?: "medium") }
    var confirmDelete by remember { mutableStateOf(false) }
    val priceValid = price.isBlank() || price.trim().toBigDecimalOrNull()?.let { it.signum() >= 0 } == true

    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        Scaffold(
            topBar = {
                TopAppBar(
                    title = { Text(if (item == null) "New item" else "Edit item") },
                    navigationIcon = {
                        IconButton(onClick = onDismiss) { Icon(Icons.Default.Close, "Cancel") }
                    },
                    actions = {
                        TextButton(
                            onClick = {
                                onSave(WishlistItemRequest(name.trim(), url.trim(), notes.trim(), price.trim(), priority))
                            },
                            enabled = name.isNotBlank() && priceValid,
                        ) { Text("Save") }
                    },
                )
            },
        ) { padding ->
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp),
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .imePadding()
                    .verticalScroll(rememberScrollState())
                    .padding(16.dp),
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("What is it?") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = price,
                    onValueChange = { price = it },
                    label = { Text("Price") },
                    prefix = { Text("£") },
                    singleLine = true,
                    isError = !priceValid,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = url,
                    onValueChange = { url = it },
                    label = { Text("Link") },
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = notes,
                    onValueChange = { notes = it },
                    label = { Text("Notes (size, colour…)") },
                    minLines = 2,
                    keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Sentences),
                    modifier = Modifier.fillMaxWidth(),
                )
                SingleChoiceSegmentedButtonRow(Modifier.fillMaxWidth()) {
                    val options = listOf("low" to "Nice to have", "medium" to "Would like", "high" to "Would love")
                    options.forEachIndexed { index, (value, label) ->
                        SegmentedButton(
                            selected = priority == value,
                            onClick = { priority = value },
                            shape = SegmentedButtonDefaults.itemShape(index, options.size),
                        ) { Text(label, maxLines = 1) }
                    }
                }
                if (item != null) {
                    TextButton(onClick = { confirmDelete = true }) {
                        Text("Delete item", color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        }
    }

    if (confirmDelete) {
        ConfirmDialog(
            title = "Delete item?",
            message = "\"${item?.name}\" will be removed from your wishlist.",
            onDismiss = { confirmDelete = false },
            onConfirm = { confirmDelete = false; onDelete() },
        )
    }
}
