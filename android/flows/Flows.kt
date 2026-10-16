// Pure logic behind the flows menu and the create-process form. No Android here, so it can be tested
// on the JVM. Field names follow https://developer.unico.io/developers/api-reference/post-processes
package io.unico.reference.flows

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject

// One row of flows.json, a copy of the root flows.json (CI fails if it drifts).
@Serializable
data class Flow(
    val id: String,
    val group: String,
    val region: String,
    val capabilities: List<String>,
    val extraFields: List<String>,
)

fun parseFlows(json: String): List<Flow> = Json.decodeFromString(json)

fun filterFlows(flows: List<Flow>, group: String, region: String): List<Flow> =
    flows.filter { it.group == group && (region == "all" || it.region == region) }

// Drops empty values, so the API only receives what the user filled in.
private fun JsonObjectBuilder.putIfSet(key: String, value: String?) {
    if (!value.isNullOrEmpty()) put(key, value)
}

// `fields` holds the form values as strings; `documentFiles` holds the document files as base64 strings.
fun buildProcessBody(flow: Flow, fields: Map<String, String>, documentFiles: List<String>, callbackUri: String): JsonObject =
    buildJsonObject {
        put("flow", flow.id)
        put("callbackUri", callbackUri)
        putJsonObject("person") {
            putIfSet("duiType", fields["duiType"])
            putIfSet("duiValue", fields["duiValue"])
            putIfSet("friendlyName", fields["friendlyName"])
            putIfSet("email", fields["email"])
            putIfSet("phone", fields["phone"])
        }

        if ("document" in flow.extraFields && documentFiles.isNotEmpty()) {
            putJsonObject("document") {
                putIfSet("purpose", fields["documentPurpose"])
                putJsonArray("files") { documentFiles.forEach { data -> addJsonObject { put("data", data) } } }
            }
        }
        if ("useCase" in flow.extraFields) putIfSet("useCase", fields["useCase"])
        val referenceProcessId = fields["referenceProcessId"]
        if ("references" in flow.extraFields && !referenceProcessId.isNullOrEmpty()) {
            putJsonArray("references") {
                addJsonObject {
                    put("referenceType", "REFERENCE_TYPE_PROCESS_ID")
                    put("referenceContent", referenceProcessId)
                }
            }
        }

        putIfSet("expiresIn", fields["expiresIn"])
        putIfSet("purpose", fields["purpose"])

        val price = fields["price"]?.toDoubleOrNull()
        val reason = fields["reason"]
        val contextualization = buildJsonObject {
            putIfSet("company_name", fields["companyName"])
            putIfSet("currency", fields["currency"])
            if (price != null) put("price", price)
            if (!reason.isNullOrEmpty()) {
                putJsonObject("locale") { putJsonObject(fields["locale"] ?: "ptBr") { put("reason", reason) } }
            }
        }
        if (contextualization.isNotEmpty()) put("contextualization", contextualization)
    }
