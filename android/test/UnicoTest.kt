package io.unico.reference.api

import com.sun.net.httpserver.HttpServer
import java.io.IOException
import java.net.InetSocketAddress
import java.net.URLDecoder
import java.security.KeyPairGenerator
import java.security.Signature
import java.util.Base64
import java.util.Collections
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.runBlocking
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class UnicoTest {
    private val keys = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
    private lateinit var fake: HttpServer
    private lateinit var baseUrl: String
    private val tokenRequests = Collections.synchronizedList(mutableListOf<Map<String, String>>())
    private val apiRequests = Collections.synchronizedList(mutableListOf<List<String>>())
    private var tokenStatus = 200

    @Before
    fun startFake() {
        fake = HttpServer.create(InetSocketAddress("127.0.0.1", 0), 0)
        fake.createContext("/") { exchange ->
            val body = exchange.requestBody.bufferedReader().readText()
            val path = exchange.requestURI.path
            val (status, contentType, payload) = if (path == "/oauth2/token") {
                tokenRequests += body.split("&").associate { pair ->
                    pair.substringBefore("=") to URLDecoder.decode(pair.substringAfter("="), "UTF-8")
                }
                if (tokenStatus == 200) {
                    Triple(200, "application/json", """{"access_token":"token-${tokenRequests.size}","token_type":"Bearer","expires_in":3600}""")
                } else {
                    Triple(tokenStatus, "application/json", """{"error":{"code":"1.2.21","message":"wrong private key"}}""")
                }
            } else {
                apiRequests += listOf(exchange.requestMethod, path, exchange.requestHeaders.getFirst("Authorization").orEmpty(), body)
                when ("${exchange.requestMethod} $path") {
                    "POST /client/v1/process" ->
                        Triple(200, "application/json", """{"process":{"id":"abc-123","webAppToken":"web-app-token"}}""")
                    "GET /client/v1/process/abc-123" ->
                        Triple(200, "application/json", """{"process":{"id":"abc-123","state":"PROCESS_STATE_FINISHED"}}""")
                    "GET /client/v1/process/abc-123/selfie" ->
                        Triple(200, "application/json", """{"fileContents":"/9j/4AAQ","contentType":"image/jpeg"}""")
                    "GET /client/v1/process/abc-123/evidenceset" ->
                        Triple(200, "application/json", """{"fileContents":"JVBERi0xLjMN","contentType":"x-pdf"}""")
                    "GET /client/v1/process/behind-gateway" -> Triple(502, "text/html", "<html>Bad Gateway</html>")
                    else -> Triple(
                        404, "application/json",
                        """{"code":5,"message":"error getting process: rpc error: code = NotFound desc = process not found"}""",
                    )
                }
            }
            val bytes = payload.toByteArray()
            exchange.responseHeaders.add("Content-Type", contentType)
            exchange.sendResponseHeaders(status, bytes.size.toLong())
            exchange.responseBody.use { it.write(bytes) }
        }
        fake.start()
        baseUrl = "http://127.0.0.1:${fake.address.port}"
    }

    @After
    fun stopFake() = fake.stop(0)

    private fun unico(hosts: Hosts = Hosts(identity = baseUrl, api = baseUrl)) =
        Unico("my-account@abc123.iam.acesso.io", keys.private, hosts)

    private fun decode(part: String) = Json.parseToJsonElement(String(Base64.getUrlDecoder().decode(part))).jsonObject

    @Test
    fun `exchanges a signed RS256 JWT for an access token`() = runBlocking {
        unico().getProcess("abc-123")

        val params = tokenRequests.single()
        assertEquals("urn:ietf:params:oauth:grant-type:jwt-bearer", params["grant_type"])
        val (header, payload, signature) = params.getValue("assertion").split(".")
        assertEquals("RS256", decode(header)["alg"]!!.jsonPrimitive.content)
        val claims = decode(payload)
        assertEquals(setOf("iss", "aud", "scope", "iat", "exp"), claims.keys)
        assertEquals("my-account@abc123.iam.acesso.io", claims["iss"]!!.jsonPrimitive.content)
        assertEquals(baseUrl, claims["aud"]!!.jsonPrimitive.content)
        assertEquals("*", claims["scope"]!!.jsonPrimitive.content)
        assertEquals(3600L, claims["exp"]!!.jsonPrimitive.long - claims["iat"]!!.jsonPrimitive.long)
        val verified = Signature.getInstance("SHA256withRSA").run {
            initVerify(keys.public)
            update("$header.$payload".toByteArray())
            verify(Base64.getUrlDecoder().decode(signature))
        }
        assertTrue(verified)
    }

    @Test
    fun `creates a process with the bearer token and returns the body as sent`() = runBlocking {
        val body = buildJsonObject { put("flow", "idlive_r2"); put("callbackUri", "/") }

        val result = unico().createProcess(body)

        assertEquals("web-app-token", result["process"]!!.jsonObject["webAppToken"]!!.jsonPrimitive.content)
        assertEquals(listOf("POST", "/client/v1/process", "Bearer token-1", body.toString()), apiRequests.single())
    }

    @Test
    fun `concurrent calls share one token request and later calls reuse it`() = runBlocking {
        val client = unico()
        listOf(async { client.getProcess("abc-123") }, async { client.getSelfie("abc-123") }).awaitAll()
        client.getEvidenceSet("abc-123")

        assertEquals(1, tokenRequests.size)
        assertEquals(
            setOf("/client/v1/process/abc-123", "/client/v1/process/abc-123/selfie", "/client/v1/process/abc-123/evidenceset"),
            apiRequests.map { it[1] }.toSet(),
        )
    }

    @Test
    fun `an API error carries the status and body as returned`() {
        val error = assertThrows(UnicoError::class.java) { runBlocking { unico().getProcess("missing") } }

        assertEquals(404, error.status)
        assertEquals(
            """{"code":5,"message":"error getting process: rpc error: code = NotFound desc = process not found"}""",
            error.body,
        )
    }

    @Test
    fun `a non-JSON error body comes back as text`() {
        val error = assertThrows(UnicoError::class.java) { runBlocking { unico().getProcess("behind-gateway") } }

        assertEquals(502, error.status)
        assertEquals("<html>Bad Gateway</html>", error.body)
    }

    @Test
    fun `a token error stops before the API call`() {
        tokenStatus = 401

        val error = assertThrows(UnicoError::class.java) { runBlocking { unico().getProcess("abc-123") } }

        assertEquals(401, error.status)
        assertTrue(error.body.contains("1.2.21"))
        assertTrue(apiRequests.isEmpty())
    }

    @Test
    fun `a malformed process id is refused before anything is sent`() {
        assertThrows(InvalidInputError::class.java) { runBlocking { unico().getSelfie("../token") } }

        assertTrue(tokenRequests.isEmpty())
        assertTrue(apiRequests.isEmpty())
    }

    @Test
    fun `a network failure surfaces as an IOException`() {
        val nothingListening = Hosts(identity = "http://127.0.0.1:1", api = "http://127.0.0.1:1")

        assertThrows(IOException::class.java) { runBlocking { unico(nothingListening).getProcess("abc-123") } }
    }
}
