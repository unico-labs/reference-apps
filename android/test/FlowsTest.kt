package io.unico.reference.flows

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class FlowsTest {
    private val person = mapOf("flow" to "idlive_r2", "duiType" to "DUI_TYPE_BR_CPF", "duiValue" to "12345678909")

    private fun json(text: String) = Json.parseToJsonElement(text)

    @Test
    fun `sends the typed flow and only the fields the user filled in`() {
        val body = buildProcessBody(person + mapOf("flow" to " idlive_r2 ", "email" to "", "purpose" to ""), emptyList(), "/")

        assertEquals(
            json("""{"flow":"idlive_r2","callbackUri":"/","person":{"duiType":"DUI_TYPE_BR_CPF","duiValue":"12345678909"}}"""),
            body,
        )
    }

    @Test
    fun `leaves the person out when no document number was typed`() {
        val body = buildProcessBody(mapOf("flow" to "idlive_r2", "duiType" to "DUI_TYPE_BR_CPF"), emptyList(), "/")

        assertEquals(json("""{"flow":"idlive_r2","callbackUri":"/"}"""), body)
    }

    @Test
    fun `maps the name, email and phone to the person`() {
        val body = buildProcessBody(
            person + mapOf("friendlyName" to "Ana", "email" to "ana@example.com", "phone" to "5511999999999"),
            emptyList(),
            "/",
        )

        assertEquals(
            json("""{"duiType":"DUI_TYPE_BR_CPF","duiValue":"12345678909","friendlyName":"Ana","email":"ana@example.com","phone":"5511999999999"}"""),
            body["person"],
        )
    }

    @Test
    fun `adds the document files and purpose when the document is turned on`() {
        val body = buildProcessBody(
            person + mapOf("withDocument" to "true", "documentPurpose" to "DOCUMENT_PURPOSE_ONBOARDING"),
            listOf("aGVsbG8="),
            "/",
        )

        assertEquals(json("""{"purpose":"DOCUMENT_PURPOSE_ONBOARDING","files":[{"data":"aGVsbG8="}]}"""), body["document"])
    }

    @Test
    fun `leaves the document out when it is turned off or has no file`() {
        assertFalse("document" in buildProcessBody(person, listOf("aGVsbG8="), "/"))
        assertFalse("document" in buildProcessBody(person + mapOf("withDocument" to "true"), emptyList(), "/"))
    }

    @Test
    fun `adds useCase and a process reference when they are turned on`() {
        val body = buildProcessBody(
            person + mapOf("withReferences" to "true", "useCase" to "USE_CASE_LOGIN", "referenceProcessId" to "abc-123"),
            emptyList(),
            "/",
        )

        assertEquals(json("\"USE_CASE_LOGIN\""), body["useCase"])
        assertEquals(json("""[{"referenceType":"REFERENCE_TYPE_PROCESS_ID","referenceContent":"abc-123"}]"""), body["references"])
    }

    @Test
    fun `leaves useCase and references out when they are turned off`() {
        val body = buildProcessBody(person + mapOf("useCase" to "USE_CASE_LOGIN", "referenceProcessId" to "abc-123"), emptyList(), "/")

        assertEquals(setOf("flow", "callbackUri", "person"), body.keys)
    }

    @Test
    fun `maps expiresIn and purpose`() {
        val body = buildProcessBody(person + mapOf("expiresIn" to "3600s", "purpose" to "creditprocess"), emptyList(), "/")

        assertEquals(json("\"3600s\""), body["expiresIn"])
        assertEquals(json("\"creditprocess\""), body["purpose"])
    }

    @Test
    fun `builds contextualization with the reason under its locale when it is turned on`() {
        val body = buildProcessBody(
            person + mapOf(
                "withContextualization" to "true", "companyName" to "Acme", "currency" to "BRL", "price" to "10.5",
                "locale" to "enUs", "reason" to "Purchase",
            ),
            emptyList(),
            "/",
        )

        assertEquals(
            json("""{"company_name":"Acme","currency":"BRL","price":10.5,"locale":{"enUs":{"reason":"Purchase"}}}"""),
            body["contextualization"] as JsonObject,
        )
    }

    @Test
    fun `leaves contextualization out when it is turned off`() {
        assertFalse("contextualization" in buildProcessBody(person + mapOf("companyName" to "Acme"), emptyList(), "/"))
    }
}
