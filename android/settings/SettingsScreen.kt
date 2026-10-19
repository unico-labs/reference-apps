// DEMO ONLY: the Connect screen. In production none of this is on the device; your server holds the credentials.
package io.unico.reference.settings

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
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
import io.unico.reference.app.Card
import io.unico.reference.app.Code
import io.unico.reference.app.Dock
import io.unico.reference.app.FieldLabel
import io.unico.reference.app.Heading
import io.unico.reference.app.Hint
import io.unico.reference.app.KeyValue
import io.unico.reference.app.Mark
import io.unico.reference.app.OkGround
import io.unico.reference.app.OkInk
import io.unico.reference.app.PrimaryButton
import io.unico.reference.app.SecondaryButton
import io.unico.reference.app.WarnGround
import io.unico.reference.app.WarnInk
import kotlinx.coroutines.launch

fun Settings.environment() = if (hosts == Hosts.PROD) "PROD" else "UAT"

// `onVerify` asks Unico for an access token with these settings. It returns an error to show, or null when the
// token came back; then the verified screen shows, and Continue saves the settings.
@Composable
fun SettingsScreen(initial: Settings, onVerify: suspend (Settings) -> String?, onContinue: (Settings) -> Unit) {
    var verified by remember { mutableStateOf<Settings?>(null) }
    verified?.let { return ConnectedScreen(it) { onContinue(it) } }

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
            Column {
                Text("Connect your Unico account", fontSize = 22.sp, fontWeight = FontWeight.ExtraBold)
                Hint("Done once. Used to sign every request.")
            }
            Text(
                "Demo only. Credentials stay on this device; in your own app, keep them on your backend.",
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
                    placeholder = { Text(if (initial.privateKeyPem.isEmpty()) "-----BEGIN PRIVATE KEY-----" else "Saved. Paste or import to replace it") },
                    textStyle = TextStyle(fontFamily = FontFamily.Monospace, fontSize = 12.sp),
                    minLines = 3, modifier = Modifier.fillMaxWidth(),
                )
                Hint("Paste it or import the file. Stored encrypted with a key from the Android Keystore.")
            }
            SecondaryButton("Import .pem file", { importPem.launch(arrayOf("*/*")) }, Modifier.fillMaxWidth())

            // https://developer.unico.io/developers/sdks-and-tools/android/installation/specific-setup
            Field("SDK key", settings.sdkKey, "Issued by Unico for the application ID below") { settings = settings.copy(sdkKey = it.trim()) }
            Field(
                "Application ID", settings.bundleIdentifier,
                "This build is ${context.packageName}. Change it only to try a key issued for another ID",
            ) { settings = settings.copy(bundleIdentifier = it.trim()) }

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
                if (sending) "Verifying…" else "Verify connection",
                enabled = !sending,
                onClick = {
                    val next = if (pem.isBlank()) settings else settings.copy(privateKeyPem = pem.trim())
                    error = when {
                        !next.isComplete -> "Fill in every field and add the private key."
                        else -> runCatching { parsePrivateKey(next.privateKeyPem) }.exceptionOrNull()
                            ?.let { it.message ?: "Not a valid RSA private key." }
                    }
                    if (error == null) {
                        sending = true
                        scope.launch {
                            error = onVerify(next)
                            if (error == null) verified = next
                            sending = false
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            )
            Hint("No service account yet? Ask Unico's onboarding team.", Modifier.fillMaxWidth().padding(top = 2.dp))
        }
    }
}

@Composable
private fun ConnectedScreen(settings: Settings, onContinue: () -> Unit) = Column(Modifier.fillMaxSize()) {
    Column(Modifier.weight(1f).padding(16.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Heading(Mark.CHECK, OkInk, OkGround, "Credentials verified", "We got a token from Unico ${settings.environment()}.")
        Card {
            KeyValue("Service account", settings.account)
            KeyValue("Tenant ID", settings.tenant)
            KeyValue("Environment", settings.environment())
        }
    }
    Dock { PrimaryButton("Continue", onContinue, Modifier.fillMaxWidth()) }
}

@Composable
private fun Field(label: String, value: String, hint: String? = null, onChange: (String) -> Unit) =
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        FieldLabel(label)
        OutlinedTextField(value, onChange, singleLine = true, modifier = Modifier.fillMaxWidth())
        hint?.let { Hint(it) }
    }
