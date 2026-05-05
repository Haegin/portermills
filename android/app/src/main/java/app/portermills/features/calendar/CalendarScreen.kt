package app.portermills.features.calendar

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarScreen(vm: CalendarViewModel = hiltViewModel()) {
    val events by vm.events.collectAsState()
    val isLoading by vm.isLoading.collectAsState()

    Scaffold(topBar = { TopAppBar(title = { Text("Calendar") }) }) { padding ->
        if (isLoading && events.isEmpty()) {
            Box(Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) {
                CircularProgressIndicator()
            }
        } else {
            LazyColumn(contentPadding = PaddingValues(
                top = padding.calculateTopPadding() + 8.dp,
                bottom = padding.calculateBottomPadding() + 8.dp,
            )) {
                items(events, key = { it.id }) { event ->
                    ListItem(
                        headlineContent = { Text(event.title) },
                        supportingContent = { Text(event.startsAt.take(10)) },
                    )
                    HorizontalDivider()
                }
            }
        }
    }
}
