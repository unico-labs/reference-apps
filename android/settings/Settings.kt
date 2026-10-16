// DEMO ONLY: credentials typed into the device. In production the service account key lives only on your server,
// which creates the process and hands the app nothing but the webAppToken. Don't copy this file into an app.
//
// What it does, for the demo: one environment (UAT hosts prefilled, editable), the service account, the SDK key,
// and the .pem key encrypted with an AES key that never leaves the Android Keystore. The manifest sets
// allowBackup="false", and a Keystore key can't be moved to another device, so the encrypted .pem is useless anywhere else.
package io.unico.reference.settings

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.unico.reference.api.Hosts
import java.security.KeyFactory
import java.security.KeyStore
import java.security.PrivateKey
import java.security.spec.PKCS8EncodedKeySpec
import java.util.Base64
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

data class Settings(
    val identityHost: String = Hosts.UAT.identity,
    val apiHost: String = Hosts.UAT.api,
    val account: String = "",
    val tenant: String = "",
    // Issued by Unico's Onboarding team for your application ID:
    // https://developer.unico.io/developers/sdks-and-tools/android/installation/specific-setup
    val sdkKey: String = "",
    // The application ID the SDK key was issued for. Defaults to this build's own (see SettingsStore.load);
    // editable only so a demo can try a key issued for another ID.
    val bundleIdentifier: String = "",
    val privateKeyPem: String = "",
) {
    val hosts get() = Hosts(identity = identityHost.trimEnd('/'), api = apiHost.trimEnd('/'))

    // The `iss` claim: https://developer.unico.io/developers/start/authentication
    val serviceAccount get() = "$account@$tenant.iam.acesso.io"

    val isComplete get() =
        listOf(identityHost, apiHost, account, tenant, sdkKey, bundleIdentifier, privateKeyPem).all { it.isNotBlank() }

    // Keeps the key out of logs and crash reports.
    override fun toString() = "Settings(identityHost=$identityHost, apiHost=$apiHost, account=$account, tenant=$tenant)"
}

// A key copied from an email often loses its PEM header or arrives in another format. Check it when it's saved,
// so the error names what was found instead of failing on the first token request.
fun parsePrivateKey(pem: String): PrivateKey {
    val header = Regex("-----BEGIN ([A-Z ]+)-----").find(pem)?.groupValues?.get(1)
    if (header != "PRIVATE KEY") {
        throw IllegalArgumentException(
            "Not a PEM private key (${header?.let { "found: $it" } ?: "no PEM header"}). " +
                "It should start with -----BEGIN PRIVATE KEY-----.",
        )
    }
    val base64 = pem.substringAfter("-----BEGIN PRIVATE KEY-----").substringBefore("-----END PRIVATE KEY-----")
    return KeyFactory.getInstance("RSA").generatePrivate(PKCS8EncodedKeySpec(Base64.getMimeDecoder().decode(base64)))
}

class SettingsStore(private val context: Context) {
    private val prefs = context.getSharedPreferences("settings", Context.MODE_PRIVATE)

    fun load(): Settings = Settings(
        identityHost = prefs.getString("identityHost", null) ?: Hosts.UAT.identity,
        apiHost = prefs.getString("apiHost", null) ?: Hosts.UAT.api,
        account = prefs.getString("account", "")!!,
        tenant = prefs.getString("tenant", "")!!,
        sdkKey = prefs.getString("sdkKey", "")!!,
        bundleIdentifier = prefs.getString("bundleIdentifier", null) ?: context.packageName,
        // If the Keystore key is gone (app data cleared, device reset), the key has to be entered again.
        privateKeyPem = prefs.getString("privateKey", null)?.let { runCatching { decrypt(it) }.getOrNull() }.orEmpty(),
    )

    fun save(settings: Settings) {
        prefs.edit()
            .putString("identityHost", settings.identityHost)
            .putString("apiHost", settings.apiHost)
            .putString("account", settings.account)
            .putString("tenant", settings.tenant)
            .putString("sdkKey", settings.sdkKey)
            .putString("bundleIdentifier", settings.bundleIdentifier)
            .putString("privateKey", encrypt(settings.privateKeyPem))
            .apply()
    }

    private fun keystoreKey(): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as SecretKey?)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(KEY_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .build(),
        )
        return generator.generateKey()
    }

    // Stored as base64(iv) + ":" + base64(ciphertext).
    private fun encrypt(plain: String): String {
        val cipher = Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, keystoreKey()) }
        val encoder = Base64.getEncoder()
        return encoder.encodeToString(cipher.iv) + ":" + encoder.encodeToString(cipher.doFinal(plain.toByteArray()))
    }

    private fun decrypt(stored: String): String {
        val (iv, data) = stored.split(":").map { Base64.getDecoder().decode(it) }
        val cipher = Cipher.getInstance(TRANSFORMATION).apply {
            init(Cipher.DECRYPT_MODE, keystoreKey(), GCMParameterSpec(128, iv))
        }
        return String(cipher.doFinal(data))
    }

    private companion object {
        const val KEY_ALIAS = "unico-reference-pem"
        const val TRANSFORMATION = "AES/GCM/NoPadding"
    }
}
