// The result after onSuccess(processId): a heading that names the result in words, the process as the API returns
// it, the selfie and the evidence set. One GET each, once. This repo's rule: no polling and no webhook.
package io.unico.reference.result

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.compose.viewModel
import io.unico.reference.api.Unico
import io.unico.reference.api.UnicoError
import io.unico.reference.app.BadGround
import io.unico.reference.app.BadInk
import io.unico.reference.app.Card
import io.unico.reference.app.Code
import io.unico.reference.app.Dock
import io.unico.reference.app.Ground
import io.unico.reference.app.Heading
import io.unico.reference.app.KeyValue
import io.unico.reference.app.Lab
import io.unico.reference.app.Line
import io.unico.reference.app.Mark
import io.unico.reference.app.Muted
import io.unico.reference.app.OkGround
import io.unico.reference.app.OkInk
import io.unico.reference.app.PrimaryButton
import io.unico.reference.app.SecondaryButton
import java.util.Base64
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.launch
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive

@OptIn(ExperimentalSerializationApi::class)
private val pretty = Json { prettyPrint = true; prettyPrintIndent = "  " }

// Errors are shown raw too: status and body exactly as Unico returned them, only indented when the body is JSON.
fun describe(error: Throwable): String {
    if (error !is UnicoError) return error.toString()
    val body = runCatching { pretty.encodeToString(JsonElement.serializer(), Json.parseToJsonElement(error.body)) }
    return "HTTP ${error.status}\n${body.getOrDefault(error.body)}"
}

private class Loaded(val process: JsonObject?, val raw: String, val selfie: ImageBitmap?, val selfieError: String?)

// Scoped to this screen's back stack entry, so coming back from the evidence set shows the same result
// instead of making the GETs again.
private class ResultModel(unico: Unico, processId: String) : ViewModel() {
    var loaded by mutableStateOf<Loaded?>(null)
        private set

    init {
        viewModelScope.launch {
            loaded = coroutineScope {
                val process = async { runCatching { unico.getProcess(processId) } }
                val selfie = async { runCatching { unico.getSelfie(processId) } }
                val selfieResult = selfie.await().mapCatching {
                    val bytes = Base64.getDecoder().decode(it.getValue("fileContents").jsonPrimitive.content)
                    BitmapFactory.decodeByteArray(bytes, 0, bytes.size).asImageBitmap()
                }
                val response = process.await()
                Loaded(
                    process = response.getOrNull()?.get("process")?.jsonObject,
                    raw = response.fold({ pretty.encodeToString(JsonElement.serializer(), it) }, ::describe),
                    selfie = selfieResult.getOrNull(),
                    selfieError = selfieResult.exceptionOrNull()?.let(::describe),
                )
            }
        }
    }
}

@Composable
fun ResultScreen(unico: Unico, processId: String, onEvidenceSet: () -> Unit, onStepUp: () -> Unit, onDone: () -> Unit) {
    val model = viewModel { ResultModel(unico, processId) }
    var viewSelfie by remember { mutableStateOf(false) }

    val result = model.loaded ?: return Column(Modifier.fillMaxSize(), horizontalAlignment = Alignment.CenterHorizontally) {
        CircularProgressIndicator(Modifier.padding(32.dp))
    }

    Column(Modifier.fillMaxSize()) {
        Column(
            Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp),
        ) {
            val process = result.process
            if (process != null) {
                val verdict = verdict(process)
                val (mark, ink, ground) = when (verdict.tone) {
                    Tone.OK -> Triple(Mark.CHECK, OkInk, OkGround)
                    Tone.BAD -> Triple(Mark.CROSS, BadInk, BadGround)
                    Tone.NEUTRAL -> Triple(Mark.DASH, Muted, Line)
                }
                val flow = process["flow"]?.jsonPrimitive?.content
                val subtitle = listOfNotNull(flow, durationSeconds(process)?.let { "$it s" }).joinToString(" · ").ifEmpty { null }
                Heading(mark, ink, ground, verdict.title, subtitle)
                Card {
                    KeyValue("Process ID", processId)
                    KeyValue("State", short(process["state"]?.jsonPrimitive?.content).orEmpty())
                    KeyValue("Result", short(process["result"]?.jsonPrimitive?.content).orEmpty())
                }
            } else {
                Heading(Mark.DASH, Muted, Line, "Result")
            }

            Card {
                Lab("Response")
                SelectionContainer { Code(result.raw) }
            }

            Card(Modifier) {
                Attachment(
                    "Selfie", if (result.selfie != null) "View" else null,
                    thumb = { result.selfie?.let { Image(it, null, Modifier.size(40.dp, 48.dp).clip(RoundedCornerShape(8.dp)), contentScale = ContentScale.Crop) } },
                ) { viewSelfie = true }
                result.selfieError?.let { Code(it) }
                HorizontalDivider(color = Line)
                Attachment("Evidence set (PDF)", "Open", onClick = onEvidenceSet)
            }
        }

        Dock {
            PrimaryButton("Try step-up on this process", onStepUp, Modifier.fillMaxWidth())
            SecondaryButton("Run another flow", onDone, Modifier.fillMaxWidth())
        }
    }

    if (viewSelfie && result.selfie != null) {
        AlertDialog(
            onDismissRequest = { viewSelfie = false },
            confirmButton = { TextButton({ viewSelfie = false }) { Text("Close") } },
            text = { Image(result.selfie, contentDescription = "Selfie captured in the journey", Modifier.fillMaxWidth()) },
        )
    }
}

@Composable
private fun Attachment(name: String, action: String?, thumb: @Composable () -> Unit = {}, onClick: () -> Unit) = Row(
    Modifier.fillMaxWidth().heightIn(min = 56.dp), verticalAlignment = Alignment.CenterVertically,
    horizontalArrangement = Arrangement.spacedBy(12.dp),
) {
    Column(Modifier.size(40.dp, 48.dp).background(Ground, RoundedCornerShape(8.dp))) { thumb() }
    Text(name, Modifier.weight(1f), fontWeight = FontWeight.Bold)
    action?.let { TextButton(onClick) { Text(it, fontWeight = FontWeight.Bold) } }
}
