// Pure logic behind the create-process form. No Android here, so it can be tested on the JVM.
// Field names follow https://developer.unico.io/developers/api-reference/post-processes
package io.unico.reference.flows

import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonObjectBuilder
import kotlinx.serialization.json.addJsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.serialization.json.putJsonArray
import kotlinx.serialization.json.putJsonObject

// Drops empty values, so the API only receives what the user filled in.
private fun JsonObjectBuilder.putIfSet(key: String, value: String?) {
    if (!value.isNullOrEmpty()) put(key, value)
}

// `fields` holds the form values as strings; `documentFiles` holds the document files as base64 strings.
// The flow is whatever the user typed: the app doesn't know which flows the account has, so a wrong or disabled
// one fails on creation. `withDocument`, `withReferences` and `withContextualization` are the switches that turn
// the extra fields on.
fun buildProcessBody(fields: Map<String, String>, documentFiles: List<String>, callbackUri: String): JsonObject =
    buildJsonObject {
        put("flow", fields["flow"].orEmpty().trim())
        put("callbackUri", callbackUri)

        // Not every flow asks for the person's document. Without its number, the type alone means nothing.
        val hasDocument = !fields["duiValue"].isNullOrEmpty()
        val person = buildJsonObject {
            if (hasDocument) putIfSet("duiType", fields["duiType"])
            putIfSet("duiValue", fields["duiValue"])
            putIfSet("friendlyName", fields["friendlyName"])
            putIfSet("email", fields["email"])
            putIfSet("phone", fields["phone"])
        }
        if (person.isNotEmpty()) put("person", person)

        if (fields["withDocument"] == "true" && documentFiles.isNotEmpty()) {
            putJsonObject("document") {
                putIfSet("purpose", fields["documentPurpose"])
                putJsonArray("files") { documentFiles.forEach { data -> addJsonObject { put("data", data) } } }
            }
        }
        val withReferences = fields["withReferences"] == "true"
        if (withReferences) putIfSet("useCase", fields["useCase"])
        val referenceProcessId = fields["referenceProcessId"]
        if (withReferences && !referenceProcessId.isNullOrEmpty()) {
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
        if (fields["withContextualization"] == "true" && contextualization.isNotEmpty()) {
            put("contextualization", contextualization)
        }
    }
