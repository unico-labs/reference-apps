// Navigation and glue. Screens: Welcome and setup (settings), Run a flow, journey (native SDK), result, evidence set.
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
import androidx.compose.runtime.LaunchedEffect
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
import io.unico.reference.settings.ConnectedScreen
import io.unico.reference.settings.CredentialsScreen
import io.unico.reference.settings.SdkSettingsScreen
import io.unico.reference.settings.Settings
import io.unico.reference.settings.SettingsStore
import io.unico.reference.settings.WelcomeScreen
import io.unico.reference.settings.environment
import io.unico.reference.settings.parsePrivateKey
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

@Serializable object WelcomeRoute
// Setup: API credentials, the connected screen, then SDK settings.
@Serializable object CredentialsRoute
@Serializable object ConnectedRoute
@Serializable object SdkSettingsRoute
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
                // The credentials verified in this run of setup, null until Verify credentials succeeds. Saved only at the last step.
                var draft by remember { mutableStateOf<Settings?>(null) }
                // Incomplete settings open Welcome first. Picked once, so saving settings doesn't rebuild the graph.
                val start: Any = remember { if (unico != null) FormRoute() else WelcomeRoute }
                // The SDK environment follows the hosts in setup: PROD hosts open the PROD journey, anything else UAT.
                val environment = if (settings.hosts == Hosts.PROD) Environment.PROD else Environment.UAT
                // Built on the first composition of onCreate, as the docs ask, and again only if setup changes the environment.
                val sdk = remember(environment) { NativeSdk(this@MainActivity, environment) }
                // The last journey finished here, offered as the reference for a step-up.
                var lastProcessId by rememberSaveable { mutableStateOf<String?>(null) }

                val destination = nav.currentBackStackEntryAsState().value?.destination
                val welcome = destination?.hasRoute<WelcomeRoute>() ?: (start == WelcomeRoute)
                val setup = destination?.hasRoute<CredentialsRoute>() == true || destination?.hasRoute<ConnectedRoute>() == true ||
                    destination?.hasRoute<SdkSettingsRoute>() == true
                val title = when {
                    setup -> "Set up this app"
                    destination?.hasRoute<ResultRoute>() == true -> "Result"
                    destination?.hasRoute<EvidenceSetRoute>() == true -> "Evidence set"
                    else -> "Run a flow"
                }

                Scaffold(containerColor = Ground, topBar = {
                    if (!welcome) Surface(color = Color.White) {
                        Column(Modifier.statusBarsPadding()) {
                            Row(
                                Modifier.fillMaxWidth().heightIn(min = 56.dp).padding(horizontal = 16.dp),
                                verticalAlignment = Alignment.CenterVertically,
                            ) {
                                Text(title, Modifier.weight(1f), fontSize = 18.sp, fontWeight = FontWeight.ExtraBold)
                                if (unico != null && !setup) {
                                    Pill(
                                        "✓ ${settings.environment()} · ${settings.account}", OkInk, OkGround,
                                        Modifier.clickable {
                                            draft = null
                                            nav.navigate(CredentialsRoute)
                                        },
                                    )
                                }
                            }
                            HorizontalDivider(color = Line)
                        }
                    }
                }) { padding ->
                    NavHost(nav, startDestination = start, modifier = Modifier.padding(padding)) {
                        composable<WelcomeRoute> {
                            WelcomeScreen { nav.navigate(CredentialsRoute) }
                        }
                        composable<CredentialsRoute> {
                            CredentialsScreen(
                                draft ?: settings,
                                onVerify = { next ->
                                    // A token proves the account, tenant and key; it says nothing about the account's flows.
                                    runCatching { Unico(next.serviceAccount, parsePrivateKey(next.privateKeyPem), next.hosts).accessToken() }
                                        .exceptionOrNull()?.let(::describe)
                                },
                                onVerified = {
                                    draft = it
                                    nav.navigate(ConnectedRoute)
                                },
                            )
                        }
                        // After the OS kills the app, the back stack comes back but the verified draft is gone: start setup again from step 1.
                        composable<ConnectedRoute> {
                            val verified = draft
                            if (verified == null) LaunchedEffect(Unit) { nav.popBackStack<CredentialsRoute>(inclusive = false) }
                            else ConnectedScreen(verified) { nav.navigate(SdkSettingsRoute) }
                        }
                        composable<SdkSettingsRoute> {
                            val verified = draft
                            if (verified == null) LaunchedEffect(Unit) { nav.popBackStack<CredentialsRoute>(inclusive = false) }
                            else SdkSettingsScreen(verified) { saved ->
                                store.save(saved)
                                settings = saved
                                nav.navigate(FormRoute()) { popUpTo(nav.graph.id) { inclusive = true } }
                            }
                        }
                        composable<FormRoute> { entry ->
                            FormScreen(lastProcessId, entry.toRoute<FormRoute>().stepUp) { body ->
                                try {
                                    val process = unico!!.createProcess(body).getValue("process").jsonObject
                                    val id = process.getValue("id").jsonPrimitive.content
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
                                sdk = sdk,
                                onFinished = { processId ->
                                    // Only a finished journey is offered as the reference for a step-up.
                                    lastProcessId = processId
                                    nav.navigate(ResultRoute(processId)) { popUpTo<FormRoute>() }
                                },
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
