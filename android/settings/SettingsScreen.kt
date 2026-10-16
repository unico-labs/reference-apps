// DEMO ONLY: the settings screen. In production none of this is on the device; your server holds the credentials.
package io.unico.reference.settings

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp

@Composable
fun SettingsScreen(initial: Settings, onSave: (Settings) -> Unit) {
    val context = LocalContext.current
    var settings by remember { mutableStateOf(initial) }
    // The stored key is never shown again. Leave the field empty to keep it.
    var pem by remember { mutableStateOf("") }
    var error by remember { mutableStateOf<String?>(null) }

    // A .pem has no registered MIME type, so the picker accepts any file and the key check below decides.
    val importPem = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            pem = context.contentResolver.openInputStream(uri)?.bufferedReader()?.use { it.readText() }.orEmpty()
        }
    }

    Column(
        Modifier.verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Settings", style = MaterialTheme.typography.headlineMedium)
        Text(
            "Hosts come filled in with UAT. See developer.unico.io/developers/start/environments.",
            style = MaterialTheme.typography.bodySmall,
        )
        OutlinedTextField(
            settings.identityHost, { settings = settings.copy(identityHost = it) },
            label = { Text("Identity host") }, singleLine = true, modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            settings.apiHost, { settings = settings.copy(apiHost = it) },
            label = { Text("API host") }, singleLine = true, modifier = Modifier.fillMaxWidth(),
        )
        OutlinedTextField(
            settings.account, { settings = settings.copy(account = it.trim()) },
            label = { Text("Unique account name") }, singleLine = true, modifier = Modifier.fillMaxWidth(),
        )
        // The JWT iss is built from these two: https://developer.unico.io/developers/start/authentication
        OutlinedTextField(
            settings.tenant, { settings = settings.copy(tenant = it.trim()) },
            label = { Text("Tenant ID") }, singleLine = true, modifier = Modifier.fillMaxWidth(),
            supportingText = {
                Text(if (settings.account.isBlank() || settings.tenant.isBlank()) "iss: <account_name>@<tenant_id>.iam.acesso.io" else "iss: ${settings.serviceAccount}")
            },
        )

        Text("Private key (.pem)", style = MaterialTheme.typography.titleMedium)
        OutlinedButton(onClick = { importPem.launch(arrayOf("*/*")) }) { Text("Import file") }
        OutlinedTextField(
            pem, { pem = it },
            label = { Text(if (initial.privateKeyPem.isEmpty()) "Or paste it here" else "Saved. Paste or import to replace it") },
            textStyle = MaterialTheme.typography.bodySmall.copy(fontFamily = FontFamily.Monospace),
            minLines = 4, modifier = Modifier.fillMaxWidth(),
        )

        OutlinedTextField(
            settings.sdkKey, { settings = settings.copy(sdkKey = it.trim()) },
            label = { Text("SDK key") }, singleLine = true, modifier = Modifier.fillMaxWidth(),
            supportingText = { Text("Issued by Unico for the application ID below") },
        )
        OutlinedTextField(
            settings.bundleIdentifier, { settings = settings.copy(bundleIdentifier = it.trim()) },
            label = { Text("Application ID") }, singleLine = true, modifier = Modifier.fillMaxWidth(),
            supportingText = { Text("This build is ${context.packageName}. Change it only to try a key issued for another ID") },
        )

        error?.let { Text(it, color = MaterialTheme.colorScheme.error) }

        Button(
            onClick = {
                val next = if (pem.isBlank()) settings else settings.copy(privateKeyPem = pem.trim())
                error = when {
                    !next.isComplete -> "Fill in every field and add the private key."
                    else -> runCatching { parsePrivateKey(next.privateKeyPem) }.exceptionOrNull()
                        ?.let { it.message ?: "Not a valid RSA private key." }
                }
                if (error == null) onSave(next)
            },
            modifier = Modifier.fillMaxWidth(),
        ) { Text("Save") }
    }
}
