// Navigation and glue. Screens: settings, flows menu, form, journey (native SDK), result, evidence set.
// Everything Unico-specific lives in the other folders; this file wires them together.
package io.unico.reference.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import com.acesso.acessobio_android.onboarding.models.Environment
import io.unico.reference.api.Hosts
import io.unico.reference.api.Unico
import io.unico.reference.flows.FlowsScreen
import io.unico.reference.flows.FormScreen
import io.unico.reference.flows.parseFlows
import io.unico.reference.journey.nativesdk.NativeSdk
import io.unico.reference.journey.nativesdk.NativeSdkJourney
import io.unico.reference.result.EvidenceSetScreen
import io.unico.reference.result.ResultScreen
import io.unico.reference.result.describe
import io.unico.reference.settings.SettingsScreen
import io.unico.reference.settings.SettingsStore
import io.unico.reference.settings.parsePrivateKey
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

@Serializable object SettingsRoute
@Serializable object FlowsRoute
@Serializable data class FormRoute(val flowId: String)
@Serializable data class JourneyRoute(val webAppToken: String)
@Serializable data class ResultRoute(val processId: String)
@Serializable data class EvidenceSetRoute(val processId: String)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val store = SettingsStore(this)
        val flows = parseFlows(assets.open("flows.json").bufferedReader().use { it.readText() })

        setContent {
            MaterialTheme {
                val nav = rememberNavController()
                var settings by remember { mutableStateOf(store.load()) }
                // DEMO ONLY: the app builds the Unico client on the device. In production, your server does.
                val unico = remember(settings) {
                    if (settings.isComplete) Unico(settings.serviceAccount, parsePrivateKey(settings.privateKeyPem), settings.hosts) else null
                }
                // Incomplete settings open Settings first. Picked once, so saving settings doesn't rebuild the graph.
                val start = remember { if (unico != null) FlowsRoute else SettingsRoute }
                // The SDK environment follows the hosts in Settings: PROD hosts open the PROD journey, anything else UAT.
                val environment = if (settings.hosts == Hosts.PROD) Environment.PROD else Environment.UAT
                // Built on the first composition of onCreate, as the docs ask, and again only if Settings change the environment.
                val sdk = remember(environment) { NativeSdk(this@MainActivity, environment) }

                Scaffold(topBar = {
                    Column(Modifier.statusBarsPadding()) {
                        // Fixed on every screen: the credentials on this device are for demonstration only.
                        Surface(color = MaterialTheme.colorScheme.errorContainer, modifier = Modifier.fillMaxWidth()) {
                            Text(
                                "Demo mode: the service account key is on this device. In production it lives only on your server.",
                                style = MaterialTheme.typography.labelMedium,
                                modifier = Modifier.padding(8.dp),
                            )
                        }
                        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), verticalAlignment = Alignment.CenterVertically) {
                            // Flows need a Unico client, so the link waits until Settings are saved.
                            TextButton(onClick = { nav.popBackStack(FlowsRoute, inclusive = false) }, enabled = unico != null) { Text("Unico API flows") }
                            Spacer(Modifier.weight(1f))
                            TextButton(onClick = { nav.navigate(SettingsRoute) }) { Text("Settings") }
                        }
                    }
                }) { padding ->
                    NavHost(
                        nav,
                        startDestination = start,
                        modifier = Modifier.padding(padding),
                    ) {
                        composable<SettingsRoute> {
                            SettingsScreen(settings) { saved ->
                                store.save(saved)
                                settings = saved
                                nav.navigate(FlowsRoute) { popUpTo(nav.graph.id) { inclusive = true } }
                            }
                        }
                        composable<FlowsRoute> {
                            FlowsScreen(flows) { nav.navigate(FormRoute(it.id)) }
                        }
                        composable<FormRoute> { entry ->
                            val flow = flows.first { it.id == entry.toRoute<FormRoute>().flowId }
                            FormScreen(flow) { body ->
                                try {
                                    val process = unico!!.createProcess(body).getValue("process").jsonObject
                                    nav.navigate(JourneyRoute(process.getValue("webAppToken").jsonPrimitive.content))
                                    null
                                } catch (e: Exception) {
                                    describe(e)
                                }
                            }
                        }
                        composable<JourneyRoute> { entry ->
                            NativeSdkJourney(
                                webAppToken = entry.toRoute<JourneyRoute>().webAppToken,
                                sdkKey = settings.sdkKey,
                                bundleIdentifier = settings.bundleIdentifier,
                                sdk = sdk,
                                onFinished = { processId -> nav.navigate(ResultRoute(processId)) { popUpTo(FlowsRoute) } },
                                onBack = { nav.popBackStack() },
                            )
                        }
                        composable<ResultRoute> { entry ->
                            val processId = entry.toRoute<ResultRoute>().processId
                            ResultScreen(
                                unico!!, processId,
                                onEvidenceSet = { nav.navigate(EvidenceSetRoute(processId)) },
                                onDone = { nav.popBackStack(FlowsRoute, inclusive = false) },
                            )
                        }
                        composable<EvidenceSetRoute> { entry ->
                            EvidenceSetScreen(unico!!, entry.toRoute<EvidenceSetRoute>().processId)
                        }
                    }
                }
            }
        }
    }
}
