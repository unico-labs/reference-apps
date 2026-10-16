package io.unico.reference.flows

import java.io.File
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class FlowsTest {
    private val flows = parseFlows(File("flows/assets/flows.json").readText())
    private fun flow(id: String) = flows.first { it.id == id }

    @Test
    fun `filters by group and region`() {
        assertEquals(listOf("idsmart_r2", "idsmart_tp1"), filterFlows(flows, "step-up", "all").map { it.id })
        assertEquals(
            listOf("idtrust_r2-idgov", "idtrustdocs_r2-idgov"),
            filterFlows(flows, "sign-up", "mexico").map { it.id },
        )
    }

    @Test
    fun `sends only the fields the user filled in`() {
        val body = buildProcessBody(
            flow("idlive_r2"),
            mapOf("duiType" to "DUI_TYPE_BR_CPF", "duiValue" to "12345678909", "email" to "", "purpose" to ""),
            emptyList(),
            "/",
        )

        assertEquals(
            Json.parseToJsonElement(
                """{"flow":"idlive_r2","callbackUri":"/","person":{"duiType":"DUI_TYPE_BR_CPF","duiValue":"12345678909"}}""",
            ),
            body,
        )
    }

    @Test
    fun `adds useCase and references for Smart Revalidation`() {
        val body = buildProcessBody(
            flow("idsmart_r2"),
            mapOf("useCase" to "USE_CASE_LOGIN", "referenceProcessId" to "abc-123"),
            emptyList(),
            "/",
        )

        assertEquals("\"USE_CASE_LOGIN\"", body["useCase"].toString())
        assertEquals(
            """[{"referenceType":"REFERENCE_TYPE_PROCESS_ID","referenceContent":"abc-123"}]""",
            body["references"].toString(),
        )
    }

    @Test
    fun `adds document files only for flows with Face Document Match`() {
        val fields = mapOf("documentPurpose" to "DOCUMENT_PURPOSE_ONBOARDING")

        val withDocs = buildProcessBody(flow("idunicodocs_r2"), fields, listOf("aGVsbG8="), "/")
        val withoutDocs = buildProcessBody(flow("idlive_r2"), fields, listOf("aGVsbG8="), "/")

        assertEquals(
            """{"purpose":"DOCUMENT_PURPOSE_ONBOARDING","files":[{"data":"aGVsbG8="}]}""",
            withDocs["document"].toString(),
        )
        assertFalse("document" in withoutDocs)
    }

    @Test
    fun `builds contextualization with the reason under its locale`() {
        val body = buildProcessBody(
            flow("idlive_r2"),
            mapOf("companyName" to "Acme", "currency" to "BRL", "price" to "10.5", "locale" to "enUs", "reason" to "Purchase"),
            emptyList(),
            "/",
        )

        assertEquals(
            Json.parseToJsonElement(
                """{"company_name":"Acme","currency":"BRL","price":10.5,"locale":{"enUs":{"reason":"Purchase"}}}""",
            ),
            body["contextualization"] as JsonObject,
        )
    }
}
