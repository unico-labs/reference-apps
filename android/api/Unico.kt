// Unico client: JWT, access token, Create Process, Get Process, selfie, evidence set.
// Plain Kotlin and the JDK only (no Android imports), so it reads the same in any JVM stack.
//
// DEMO ONLY: this app signs the JWT on the device because it has no server. In production this whole file
// runs on your server and the device never holds the service account key. See web/api/unico.js for the same
// client on a server, and https://developer.unico.io/developers/start/authentication ("Never do this on the client side").
package io.unico.reference.api

import java.net.HttpURLConnection
import java.net.URI
import java.net.URLEncoder
import java.security.PrivateKey
import java.security.Signature
import java.util.Base64
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlinx.serialization.json.long
import kotlinx.serialization.json.put

// https://developer.unico.io/developers/start/environments
data class Hosts(val identity: String, val api: String) {
    companion object {
        val UAT = Hosts(identity = "https://identityhomolog.acesso.io", api = "https://api.idcloud.uat.unico.app")
        val PROD = Hosts(identity = "https://identity.acesso.io", api = "https://api.idcloud.unico.app")
    }
}

// Any non-2xx answer from Unico, with the status and body exactly as returned.
class UnicoError(val status: Int, val body: String) : Exception("Unico API returned $status")

// Bad input caught here, before anything is sent to Unico.
class InvalidInputError(message: String) : Exception(message)

// The docs ask for proactive renewal when 10 minutes or less remain.
private const val RENEW_BEFORE_MS = 10 * 60 * 1000L

// Judgment call: long enough for a slow mobile network, short enough that a dead connection surfaces as an error.
private const val TIMEOUT_MS = 30_000

// Ids are interpolated into the URL, so anything like `../` is refused before calling Unico.
private fun processId(id: String): String {
    if (!Regex("^[\\w-]+$").matches(id)) throw InvalidInputError("invalid process id")
    return id
}

class Unico(
    private val serviceAccount: String,
    private val privateKey: PrivateKey,
    private val hosts: Hosts,
) {
    private val tokenLock = Mutex()
    private var accessToken: String? = null
    private var renewAt = 0L

    // https://developer.unico.io/developers/start/authentication
    // DEMO ONLY: signs with the service account key held on the device. Don't copy this into an app.
    private fun signAssertion(): String {
        val now = System.currentTimeMillis() / 1000
        val header = buildJsonObject { put("alg", "RS256"); put("typ", "JWT") }
        // Only these claims: any other (sub, jti, nbf) is refused with error 1.2.22.
        val payload = buildJsonObject {
            put("iss", serviceAccount)
            put("aud", hosts.identity)
            put("scope", "*")
            put("iat", now)
            put("exp", now + 3600)
        }
        val b64 = Base64.getUrlEncoder().withoutPadding()
        val signingInput = b64.encodeToString(header.toString().toByteArray()) + "." +
            b64.encodeToString(payload.toString().toByteArray())
        val signature = Signature.getInstance("SHA256withRSA").run {
            initSign(privateKey)
            update(signingInput.toByteArray())
            sign()
        }
        return signingInput + "." + b64.encodeToString(signature)
    }

    private suspend fun requestToken(): String {
        val form = "grant_type=" + URLEncoder.encode("urn:ietf:params:oauth:grant-type:jwt-bearer", "UTF-8") +
            "&assertion=" + URLEncoder.encode(signAssertion(), "UTF-8")
        val (status, text) = send("POST", "${hosts.identity}/oauth2/token", null, "application/x-www-form-urlencoded", form)
        if (status !in 200..299) throw UnicoError(status, text)

        val data = parse(status, text)
        val token = data.getValue("access_token").jsonPrimitive.content
        accessToken = token
        renewAt = System.currentTimeMillis() + data.getValue("expires_in").jsonPrimitive.long * 1000 - RENEW_BEFORE_MS
        return token
    }

    // Concurrent callers share one request. Two assertions signed in the same second are identical,
    // and Unico refuses a reused JWT (error 1.2.7).
    private suspend fun token(): String = tokenLock.withLock {
        accessToken?.takeIf { System.currentTimeMillis() < renewAt } ?: requestToken()
    }

    private suspend fun call(method: String, path: String, body: JsonObject? = null): JsonObject {
        val (status, text) = send(method, "${hosts.api}$path", token(), "application/json", body?.toString())
        if (status !in 200..299) throw UnicoError(status, text)
        return parse(status, text)
    }

    // https://developer.unico.io/developers/api-reference/post-processes → { process }
    suspend fun createProcess(body: JsonObject): JsonObject = call("POST", "/client/v1/process", body)

    // https://developer.unico.io/developers/api-reference/get-process → { process }
    suspend fun getProcess(id: String): JsonObject = call("GET", "/client/v1/process/${processId(id)}")

    // https://developer.unico.io/developers/api-reference/get-selfie → { fileContents, contentType }
    suspend fun getSelfie(id: String): JsonObject = call("GET", "/client/v1/process/${processId(id)}/selfie")

    // https://developer.unico.io/developers/api-reference/get-evidence-set → { fileContents, contentType }
    // fileContents is a base64 PDF. contentType comes back as "x-pdf", not the "application/pdf" the docs show.
    suspend fun getEvidenceSet(id: String): JsonObject =
        call("GET", "/client/v1/process/${processId(id)}/evidenceset")
}

// A 2xx answer that isn't a JSON object is still Unico's answer, so it surfaces as a UnicoError with the body as sent.
private fun parse(status: Int, text: String): JsonObject =
    runCatching { Json.parseToJsonElement(text).jsonObject }.getOrElse { throw UnicoError(status, text) }

// Plain HttpURLConnection: one request, status and body text back. Network failures throw IOException.
private suspend fun send(
    method: String,
    url: String,
    bearer: String?,
    contentType: String,
    body: String?,
): Pair<Int, String> = withContext(Dispatchers.IO) {
    val connection = URI(url).toURL().openConnection() as HttpURLConnection
    try {
        connection.requestMethod = method
        connection.connectTimeout = TIMEOUT_MS
        connection.readTimeout = TIMEOUT_MS
        connection.setRequestProperty("Content-Type", contentType)
        if (bearer != null) connection.setRequestProperty("Authorization", "Bearer $bearer")
        if (body != null) {
            connection.doOutput = true
            connection.outputStream.use { it.write(body.toByteArray()) }
        }
        val status = connection.responseCode
        val stream = if (status in 200..299) connection.inputStream else connection.errorStream
        status to (stream?.bufferedReader()?.use { it.readText() } ?: "")
    } finally {
        connection.disconnect()
    }
}
