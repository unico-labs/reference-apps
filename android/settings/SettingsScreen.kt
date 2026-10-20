// DEMO ONLY: the setup screens. In production none of this is on the device; your server holds the credentials.
// Step 1 takes the API credentials and checks them, step 2 takes the SDK key. Nothing is saved until step 2.
package io.unico.reference.settings

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.unico.reference.api.Hosts
import io.unico.reference.app.Accent
import io.unico.reference.app.Card
import io.unico.reference.app.Code
import io.unico.reference.app.Dock
import io.unico.reference.app.ExtraBox
import io.unico.reference.app.FieldLabel
import io.unico.reference.app.Heading
import io.unico.reference.app.Hint
import io.unico.reference.app.KeyValue
import io.unico.reference.app.Line
import io.unico.reference.app.Link
import io.unico.reference.app.Mark
import io.unico.reference.app.Muted
import io.unico.reference.app.OkGround
import io.unico.reference.app.OkInk
import io.unico.reference.app.PrimaryButton
import io.unico.reference.app.SecondaryButton
import io.unico.reference.app.WarnGround
import io.unico.reference.app.WarnInk
import kotlinx.coroutines.launch

fun Settings.environment() = if (hosts == Hosts.PROD) "PROD" else "UAT"

const val AUTHENTICATION_GUIDE = "https://developer.unico.io/developers/start/authentication"
const val ANDROID_SETUP = "https://developer.unico.io/developers/sdks-and-tools/android/installation/specific-setup"

// Step 1. `onVerify` asks Unico for an access token with these settings. It returns an error to show, or null when
// the token came back; then `onVerified` gets the settings to carry to step 2.
@Composable
fun CredentialsScreen(initial: Settings, onVerify: suspend (Settings) -> String?, onVerified: (Settings) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var settings by remember { mutableStateOf(initial) }
    // The stored key is never shown again. Leave the field empty to keep it.
    var pem by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }
    var sending by remember { mutableStateOf(false) }
    var advanced by remember { mutableStateOf(false) }

    // A .pem has no registered MIME type, so the picker accepts any file and the key check below decides.
    val importPem = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            pem = context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }.orEmpty()
        }
    }

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Progress("Step 1 of 2", filled = 1)
            Title("API credentials", "Used to create the process when you start a test.")
            Text(
                "Demo only. Credentials stay on this device. In your own app, keep them on your backend.",
                Modifier.fillMaxWidth().background(WarnGround, RoundedCornerShape(10.dp)).padding(horizontal = 12.dp, vertical = 9.dp),
                color = WarnInk, fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
            )

            Field("Service account", settings.account, "Your unique account name") { settings = settings.copy(account = it.trim()) }
            // The JWT iss is built from these two: https://developer.unico.io/developers/start/authentication
            Field(
                "Tenant ID", settings.tenant,
                if (settings.account.isBlank() || settings.tenant.isBlank()) "iss: <account_name>@<tenant_id>.iam.acesso.io"
                else "iss: ${settings.serviceAccount}",
            ) { settings = settings.copy(tenant = it.trim()) }

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                FieldLabel("Private key (.pem)")
                OutlinedTextField(
                    pem, { pem = it },
                    placeholder = { Text(if (initial.privateKeyPem.isEmpty()) "-----BEGIN PRIVATE KEY-----" else "Key added. Paste or import to replace it") },
                    textStyle = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 12.sp),
                    minLines = 3, modifier = Modifier.fillMaxWidth(),
                )
                Hint("Paste it or import the file. Saved at the last step, encrypted with a key from the Android Keystore.")
            }
            SecondaryButton("Import .pem file", { importPem.launch(arrayOf("*/*")) }, Modifier.fillMaxWidth())

            Tip("Unico provides all three when it creates your service account. Never ship the private key inside a mobile app.")
            Link("Authentication guide ↗", AUTHENTICATION_GUIDE)

            TextButton(onClick = { advanced = !advanced }) {
                Text(if (advanced) "Hide API endpoints" else "API endpoints (advanced)", fontWeight = FontWeight.Bold)
            }
            if (advanced) {
                // https://developer.unico.io/developers/start/environments
                Field("Identity host", settings.identityHost) { settings = settings.copy(identityHost = it) }
                Field("API host", settings.apiHost) { settings = settings.copy(apiHost = it) }
            }

            error?.let { Card { Code(it) } }
        }

        Dock {
            PrimaryButton(
                if (sending) "Verifying…" else "Verify credentials",
                enabled = !sending,
                onClick = {
                    val next = if (pem.isBlank()) settings else settings.copy(privateKeyPem = pem.trim())
                    error = when {
                        !next.hasCredentials -> "Fill in every field and add the private key."
                        else -> runCatching { parsePrivateKey(next.privateKeyPem) }.exceptionOrNull()
                            ?.let { it.message ?: "Not a valid RSA private key." }
                    }
                    if (error == null) {
                        sending = true
                        scope.launch {
                            error = onVerify(next)
                            sending = false
                            if (error == null) onVerified(next)
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

// Between the steps: what Unico accepted.
@Composable
fun ConnectedScreen(settings: Settings, onContinue: () -> Unit) = Column(Modifier.fillMaxSize()) {
    Column(
        Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        Progress("Step 1 of 2 · done", filled = 1)
        Heading(Mark.CHECK, OkInk, OkGround, "Connected to the API", "Unico ${settings.environment()} accepted your credentials.")
        Card {
            KeyValue("Service account", settings.account)
            KeyValue("Tenant ID", settings.tenant)
            KeyValue("Environment", settings.environment())
        }
        Text("One more step: the SDK settings, so the camera experience can open.")
    }
    Dock { PrimaryButton("Continue to SDK settings", onContinue, Modifier.fillMaxWidth()) }
}

// Step 2. The app ID is this build's own: the SDK only opens for the ID Unico linked to the SDK key.
// `onSave` gets the settings from step 1 with the SDK key added.
@Composable
fun SdkSettingsScreen(initial: Settings, onSave: (Settings) -> Unit) {
    var sdkKey by remember { mutableStateOf(initial.sdkKey) }
    var error by remember { mutableStateOf<String?>(null) }

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            Progress("Step 2 of 2", filled = 2)
            Title("SDK settings", "Used to open the camera experience.")
            // https://developer.unico.io/developers/sdks-and-tools/android/installation/specific-setup
            Field("SDK key", sdkKey, placeholder = "Paste the key Unico issued") { sdkKey = it.trim() }
            Field(
                "App ID", LocalContext.current.packageName,
                "Application ID of this app. The SDK key must be issued for it.", readOnly = true,
            ) {}
            Tip(
                "Ask Unico's Onboarding team for an SDK key linked to your app ID. We don't check it here. " +
                    "If the camera doesn't open, review the key and the app ID.",
            )
            Link("Android setup ↗", ANDROID_SETUP)
            error?.let { Card { Code(it) } }
        }
        Dock {
            PrimaryButton(
                "Save and continue",
                onClick = {
                    val saved = initial.copy(sdkKey = sdkKey)
                    error = when {
                        sdkKey.isBlank() -> "Fill in the SDK key."
                        !saved.isComplete -> "Go back and verify the API credentials first."
                        else -> null
                    }
                    if (error == null) onSave(saved)
                },
                modifier = Modifier.fillMaxWidth(),
            )
        }
    }
}

@Composable
private fun Progress(label: String, filled: Int) = Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
    Text(label, color = Muted, fontSize = 12.sp, fontWeight = FontWeight.Bold)
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        repeat(2) { Box(Modifier.weight(1f).height(4.dp).background(if (it < filled) Accent else Line, CircleShape)) }
    }
}

@Composable
private fun Title(title: String, subtitle: String) = Column {
    Text(title, fontSize = 22.sp, fontWeight = FontWeight.ExtraBold)
    Hint(subtitle)
}

@Composable
private fun Tip(text: String) = ExtraBox { Text(text, fontSize = 13.sp) }

@Composable
private fun Field(
    label: String,
    value: String,
    hint: String? = null,
    placeholder: String? = null,
    readOnly: Boolean = false,
    onChange: (String) -> Unit,
) = Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
    FieldLabel(label)
    OutlinedTextField(
        value, onChange, singleLine = true, readOnly = readOnly, modifier = Modifier.fillMaxWidth(),
        placeholder = placeholder?.let { { Text(it) } },
    )
    hint?.let { Hint(it) }
}
