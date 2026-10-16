// The result after onSuccess(processId): the process as the API returns it, without interpreting it, plus the selfie
// and a button for the evidence set. One GET each, once. This repo's rule: no polling and no webhook.
package io.unico.reference.result

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import io.unico.reference.api.Unico
import io.unico.reference.api.UnicoError
import java.util.Base64
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.jsonPrimitive

private val pretty = Json { prettyPrint = true }

// Errors are shown raw too: status and body exactly as Unico returned them, only indented when the body is JSON.
fun describe(error: Throwable): String {
    if (error !is UnicoError) return error.toString()
    val body = runCatching { pretty.encodeToString(JsonElement.serializer(), Json.parseToJsonElement(error.body)) }
    return "HTTP ${error.status}\n${body.getOrDefault(error.body)}"
}

private class Loaded(val process: String, val selfie: ImageBitmap?, val selfieError: String?)

@Composable
fun ResultScreen(unico: Unico, processId: String, onEvidenceSet: () -> Unit, onDone: () -> Unit) {
    var loaded by remember { mutableStateOf<Loaded?>(null) }

    LaunchedEffect(processId) {
        loaded = coroutineScope {
            val process = async { runCatching { unico.getProcess(processId) } }
            val selfie = async { runCatching { unico.getSelfie(processId) } }
            val selfieResult = selfie.await().mapCatching {
                val bytes = Base64.getDecoder().decode(it.getValue("fileContents").jsonPrimitive.content)
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size).asImageBitmap()
            }
            Loaded(
                process = process.await().fold({ pretty.encodeToString(JsonElement.serializer(), it) }, ::describe),
                selfie = selfieResult.getOrNull(),
                selfieError = selfieResult.exceptionOrNull()?.let(::describe),
            )
        }
    }

    Column(
        Modifier.verticalScroll(rememberScrollState()).padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Text("Result", style = MaterialTheme.typography.headlineMedium)
        val result = loaded
        if (result == null) {
            CircularProgressIndicator()
            return@Column
        }

        Text("GET /client/v1/process/{id}", style = MaterialTheme.typography.titleMedium)
        SelectionContainer { Text(result.process, fontFamily = FontFamily.Monospace, style = MaterialTheme.typography.bodySmall) }

        Text("GET /client/v1/process/{id}/selfie", style = MaterialTheme.typography.titleMedium)
        result.selfie?.let { Image(it, contentDescription = "Selfie captured in the journey", Modifier.fillMaxWidth()) }
        result.selfieError?.let { Text(it, fontFamily = FontFamily.Monospace) }

        Text("GET /client/v1/process/{id}/evidenceset", style = MaterialTheme.typography.titleMedium)
        Button(onClick = onEvidenceSet) { Text("Open evidence set (PDF)") }

        OutlinedButton(onClick = onDone) { Text("Run another flow") }
    }
}
