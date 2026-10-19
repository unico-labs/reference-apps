// Navigation and glue. Screens: Connect (settings), Run a flow, journey (native SDK), result, evidence set.
// Everything Unico-specific lives in the other folders; this file wires them together.
package io.unico.reference.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavDestination.Companion.hasRoute
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.toRoute
import com.acesso.acessobio_android.onboarding.models.Environment
import io.unico.reference.api.Hosts
import io.unico.reference.api.Unico
import io.unico.reference.flows.FormScreen
import io.unico.reference.journey.nativesdk.NativeSdk
import io.unico.reference.journey.nativesdk.NativeSdkJourney
import io.unico.reference.result.EvidenceSetScreen
import io.unico.reference.result.ResultScreen
import io.unico.reference.result.describe
import io.unico.reference.settings.SettingsScreen
import io.unico.reference.settings.SettingsStore
import io.unico.reference.settings.environment
import io.unico.reference.settings.parsePrivateKey
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

@Serializable object SettingsRoute
// `stepUp` turns on the reference to the last process, from Try step-up on the result screen.
@Serializable data class FormRoute(val stepUp: Boolean = false)
@Serializable data class JourneyRoute(val webAppToken: String, val flow: String, val processId: String)
@Serializable data class ResultRoute(val processId: String)
@Serializable data class EvidenceSetRoute(val processId: String)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        val store = SettingsStore(this)

        setContent {
            ReferenceTheme {
                val nav = rememberNavController()
                var settings by remember { mutableStateOf(store.load()) }
                // DEMO ONLY: the app builds the Unico client on the device. In production, your server does.
                val unico = remember(settings) {
                    if (settings.isComplete) Unico(settings.serviceAccount, parsePrivateKey(settings.privateKeyPem), settings.hosts) else null
                }
                // Incomplete settings open Connect first. Picked once, so saving settings doesn't rebuild the graph.
                val start: Any = remember { if (unico != null) FormRoute() else SettingsRoute }
                // The SDK environment follows the hosts in Connect: PROD hosts open the PROD journey, anything else UAT.
                val environment = if (settings.hosts == Hosts.PROD) Environment.PROD else Environment.UAT
                // Built on the first composition of onCreate, as the docs ask, and again only if Connect changes the environment.
                val sdk = remember(environment) { NativeSdk(this@MainActivity, environment) }
                // The last process created here, offered as the reference for a step-up.
                var lastProcessId by rememberSaveable { mutableStateOf<String?>(null) }

                val destination = nav.currentBackStackEntryAsState().value?.destination
                val title = when {
                    destination?.hasRoute<SettingsRoute>() == true -> "Connect"
                    destination?.hasRoute<ResultRoute>() == true -> "Result"
                    destination?.hasRoute<EvidenceSetRoute>() == true -> "Evidence set"
                    else -> "Run a flow"
                }

                Scaffold(containerColor = Ground, topBar = {
                    Surface(color = Color.White) {
                        Column(Modifier.statusBarsPadding()) {
                            Row(
                                Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = 16.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(title, Modifier.weight(1f), fontSize = 18.sp, fontWeight = FontWeight.ExtraBold)
                                if (unico != null && destination?.hasRoute<SettingsRoute>() != true) {
                                    Pill(
                                        "✓ ${settings.environment()} · ${settings.account}", OkInk, OkGround,
                                        Modifier.clickable { nav.navigate(SettingsRoute) },
                                    )
                                }
                            }
                            HorizontalDivider(color = Line)
                        }
                    }
                }) { padding ->
                    NavHost(nav, startDestination = start, modifier = Modifier.padding(padding)) {
                        composable<SettingsRoute> {
                            SettingsScreen(
                                settings,
                                onVerify = { next ->
                                    // A token proves the account, tenant and key; it says nothing about the account's flows.
                                    runCatching { Unico(next.serviceAccount, parsePrivateKey(next.privateKeyPem), next.hosts).accessToken() }
                                        .exceptionOrNull()?.let(::describe)
                                },
                                onContinue = { saved ->
                                    store.save(saved)
                                    settings = saved
                                    nav.navigate(FormRoute()) { popUpTo(nav.graph.id) { inclusive = true } }
                                },
                            )
                        }
                        composable<FormRoute> { entry ->
                            FormScreen(lastProcessId, entry.toRoute<FormRoute>().stepUp) { body ->
                                try {
                                    val process = unico!!.createProcess(body).getValue("process").jsonObject
                                    val id = process.getValue("id").jsonPrimitive.content
                                    lastProcessId = id
                                    nav.navigate(JourneyRoute(process.getValue("webAppToken").jsonPrimitive.content, body.getValue("flow").jsonPrimitive.content, id))
                                    null
                                } catch (e: Exception) {
                                    describe(e)
                                }
                            }
                        }
                        composable<JourneyRoute> { entry ->
                            val route = entry.toRoute<JourneyRoute>()
                            NativeSdkJourney(
                                webAppToken = route.webAppToken,
                                flow = route.flow,
                                processId = route.processId,
                                sdkKey = settings.sdkKey,
                                bundleIdentifier = settings.bundleIdentifier,
                                sdk = sdk,
                                onFinished = { processId -> nav.navigate(ResultRoute(processId)) { popUpTo<FormRoute>() } },
                                onBack = { nav.popBackStack() },
                            )
                        }
                        composable<ResultRoute> { entry ->
                            val processId = entry.toRoute<ResultRoute>().processId
                            ResultScreen(
                                unico!!, processId,
                                onEvidenceSet = { nav.navigate(EvidenceSetRoute(processId)) },
                                onStepUp = {
                                    lastProcessId = processId
                                    nav.navigate(FormRoute(stepUp = true)) { popUpTo(nav.graph.id) { inclusive = true } }
                                },
                                onDone = { nav.navigate(FormRoute()) { popUpTo(nav.graph.id) { inclusive = true } } },
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
