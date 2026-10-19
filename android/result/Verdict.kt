// The heading of the result screen. It only names the result the API returned, in words:
// https://developer.unico.io/developers/api-reference/get-process. The JSON on screen stays as returned.
package io.unico.reference.result

import java.time.Duration
import java.time.Instant
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.jsonPrimitive

enum class Tone { OK, BAD, NEUTRAL }

data class Verdict(val title: String, val tone: Tone)

fun short(value: String?) = value?.removePrefix("PROCESS_RESULT_")?.removePrefix("PROCESS_STATE_")

// PROCESS_RESULT_OK reads "Success" in green, a definitive negative or an error in red, anything else in grey.
fun verdict(process: JsonObject): Verdict {
    val result = short(process["result"]?.jsonPrimitive?.content)
    if (result == "OK") return Verdict("Success", Tone.OK)
    val tone = if (result == "INVALID_IDENTITY" || result == "ERROR") Tone.BAD else Tone.NEUTRAL
    val words = (result ?: short(process["state"]?.jsonPrimitive?.content)).orEmpty().replace('_', ' ').lowercase()
    return Verdict(words.replaceFirstChar { it.uppercase() }.ifEmpty { "Result" }, tone)
}

fun durationSeconds(process: JsonObject): Long? {
    val created = process["createdAt"]?.jsonPrimitive?.content ?: return null
    val finished = process["finishedAt"]?.jsonPrimitive?.content ?: return null
    // The docs say UTC without the exact format, and on older Android versions Instant.parse takes only a trailing Z.
    // A timestamp that doesn't parse leaves the duration out instead of failing the screen.
    return runCatching { Duration.between(Instant.parse(created), Instant.parse(finished)).seconds }.getOrNull()
}
