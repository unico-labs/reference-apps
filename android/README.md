# Android (Jetpack Compose, native SDK)

One Compose app that creates a process, opens the journey with Unico's native SDK (`io.unico:capture`) using the process's `webAppToken`, and shows the process JSON, the selfie and the evidence set PDF as returned.

> **Demo mode.** With no server, the app takes the service account key on the Connect screen and calls Unico from the device. Never do this in a real app: anything shipped to a device is public. In production your server holds the key and creates the process; see [`../web/`](../web/).

## Run

Requires JDK 17 or later (Android Studio ships one; running from Android Studio needs nothing else), the Android SDK (platform 37), a **physical device** (the SDK refuses emulators) and:

- UAT credentials: unique account name, tenant ID and `.pem` private key, as in [Authentication](https://developer.unico.io/developers/start/authentication). The app builds the JWT `iss` from the first two (see the root [README](../README.md#credentials));
- an SDK key from Unico's Onboarding team, linked to the app's `applicationId`. Set `applicationId` in [`build.gradle.kts`](build.gradle.kts) to the one Unico linked. For a demo, Settings also lets you type another ID without rebuilding.

From a terminal, set `JAVA_HOME` to Android Studio's bundled JDK (on macOS, `/Applications/Android Studio.app/Contents/jbr/Contents/Home`) and `ANDROID_HOME` to the Android SDK (on macOS, `~/Library/Android/sdk`), or put `sdk.dir` in `local.properties`.

```sh
./gradlew installDebug
```

Or open this folder in Android Studio and run it from there.

On the device, fill in Connect: the **Service account**, tenant ID, the `.pem` key (imported from a file or pasted), the SDK key and the application ID. The hosts come filled in with UAT under API endpoints. **Verify connection** asks Unico for a token before saving. Then type the name of a flow your account has (see [Flows](https://developer.unico.io/developers/start/flows)), add your own document and tap **Start test**. Customize holds the optional and extra fields.

## Test

The tests run on the JVM against a local fake of the Unico endpoints and need no credentials or device.

```sh
./gradlew test
```

## Using `api/Unico.kt` as a reference

[`api/Unico.kt`](api/Unico.kt) shows every Unico call this app makes, with only the JDK, kotlinx.serialization and kotlinx.coroutines. It signs the JWT as in [Authentication](https://developer.unico.io/developers/start/authentication), caches the access token and renews it when 10 minutes or less remain. On a device it is demo code; on a JVM server it is the same client.

```kotlin
val unico = Unico("my-account@abc123.iam.acesso.io", privateKey, Hosts.UAT)

try {
    val body = buildJsonObject {
        put("flow", "idlive_r2")
        put("callbackUri", "/") // the native SDK handles the return in-app
        putJsonObject("person") { put("duiType", "DUI_TYPE_BR_CPF"); put("duiValue", "12345678909") }
    }
    val process = unico.createProcess(body).getValue("process").jsonObject
    // process is { id, webAppToken, ... }: open the native SDK with process["webAppToken"].
} catch (e: UnicoError) {
    println("${e.status} ${e.body}")
}
```

`accessToken()` returns the cached access token, or asks for a new one: call it to check the credentials without calling the API, as the Connect screen does. A token proves the account, tenant and key, not which flows the account has. `getProcess(id)` returns `{ "process": { id, state, result, ... } }`. `getSelfie(id)` and `getEvidenceSet(id)` return `{ fileContents, contentType }`, with the file in base64. Every non-2xx answer from Unico throws a `UnicoError` with the status and body as returned. A malformed process id throws an `InvalidInputError` before anything is sent. Network failures throw `IOException`.

## Code

[`AGENTS.md`](AGENTS.md) explains where each piece is, how the native SDK opens and returns, and what to change when you build your own app.
