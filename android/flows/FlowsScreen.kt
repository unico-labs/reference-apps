// The flows menu: Sign-up × Step-up, filtered by region. Same choices as web/views/menu.ejs.
package io.unico.reference.flows

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ListItem
import androidx.compose.material3.PrimaryTabRow
import androidx.compose.material3.Tab
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp

private val GROUPS = listOf("sign-up" to "Sign-up", "step-up" to "Step-up")
private val REGIONS = listOf("all" to "All", "global" to "Global", "brazil" to "Brazil", "mexico" to "Mexico")

@Composable
fun FlowsScreen(flows: List<Flow>, onPick: (Flow) -> Unit) {
    var group by rememberSaveable { mutableStateOf("sign-up") }
    var region by rememberSaveable { mutableStateOf("all") }
    val shown = filterFlows(flows, group, region)

    Column {
        PrimaryTabRow(selectedTabIndex = GROUPS.indexOfFirst { it.first == group }) {
            GROUPS.forEach { (key, label) -> Tab(selected = key == group, onClick = { group = key }, text = { Text(label) }) }
        }
        Row(Modifier.horizontalScroll(rememberScrollState()).padding(8.dp)) {
            REGIONS.forEach { (key, label) ->
                FilterChip(
                    selected = key == region, onClick = { region = key }, label = { Text(label) },
                    modifier = Modifier.padding(horizontal = 4.dp),
                )
            }
        }
        LazyColumn {
            items(shown, key = { it.id }) { flow ->
                ListItem(
                    headlineContent = { Text(flow.id, fontFamily = FontFamily.Monospace) },
                    supportingContent = { Text("${flow.region} · ${flow.capabilities.joinToString(" · ")}") },
                    modifier = Modifier.fillMaxWidth().clickable { onPick(flow) },
                )
                HorizontalDivider()
            }
            if (shown.isEmpty()) item { Text("No $group flows for this region.", Modifier.padding(16.dp)) }
        }
    }
}
