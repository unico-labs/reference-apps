# iOS (SwiftUI, native SDK)

One SwiftUI app that creates a process, opens the journey with Unico's native SDK (`unicocheck-ios`, module `AcessoBio`) using the process's `webAppToken`, and shows the process JSON, the selfie and the evidence set PDF as returned.

> **Demo mode.** With no server, the app takes the service account key on the setup screens and calls Unico from the device. Never do this in a real app: anything shipped to a device is public. In production your server holds the key and creates the process; see [`../web/`](../web/).

## Run

Requires a Mac with Xcode 16 or later (as the SDK's [requirements](https://developer.unico.io/developers/sdks-and-tools/ios/requirements) ask), [XcodeGen](https://github.com/yonaskolb/XcodeGen) (tested with 2.46.0), an **iPhone** (the SDK refuses simulators) and:

- UAT credentials: unique account name, tenant ID and `.pem` private key, as in [Authentication](https://developer.unico.io/developers/start/authentication). The app builds the JWT `iss` from the first two. See the root [README](../README.md#credentials).
- an SDK key from Unico's Onboarding team, linked to the app's Bundle Identifier ([Specific setup](https://developer.unico.io/developers/sdks-and-tools/ios/installation/specific-setup)). Set `PRODUCT_BUNDLE_IDENTIFIER` in [`project.yml`](project.yml) to the one Unico linked, and `DEVELOPMENT_TEAM` to your Apple Developer Team ID so Xcode can sign the app for your iPhone.

The app runs on iOS 17 and later because its SwiftUI screens need it; the SDK itself supports iOS 13, so your app can go lower. The Xcode project and `app/Info.plist` are generated from `project.yml`, so they stay readable in review:

```sh
brew install xcodegen
xcodegen generate
open UnicoReference.xcodeproj
```

Xcode fetches the SDK through Swift Package Manager. Pick your iPhone and run.

On the device, tap **Get started** on the welcome screen. Step 1, API credentials, asks for the Service account (your unique account name), Tenant ID and Private key (.pem), pasted or imported from Files. The hosts come filled in with UAT under API endpoints (advanced). **Verify credentials** asks Unico for a token. Step 2, SDK settings, asks for the SDK key and shows the App ID, this build's Bundle Identifier, read-only; **Save and continue** stores both steps. Then type the name of a flow your account has (see [Flows](https://developer.unico.io/developers/start/flows)), add your own document and tap **Start test**. Customize holds the optional and extra fields. On Run a flow, the `✓ UAT · <account>` pill at the top opens step 1 again.

## Test

The tests run on the Mac against a local fake of the Unico endpoints and need no credentials, device or simulator.

```sh
swift test
```

## Using `api/Unico.swift` as a reference

[`api/Unico.swift`](api/Unico.swift) shows every Unico call this app makes, with only Foundation and Security. It signs the JWT as in [Authentication](https://developer.unico.io/developers/start/authentication), caches the access token and renews it when 10 minutes or less remain. On a device it is demo code; in a Swift server it is the same client.

```swift
let unico = Unico(serviceAccount: "my-account@abc123.iam.acesso.io", privateKey: privateKey, hosts: .uat)

do {
    let response = try await unico.createProcess([
        "flow": "idlive_r2",
        "callbackUri": "/", // the native SDK handles the return in-app
        "person": ["duiType": "DUI_TYPE_BR_CPF", "duiValue": "12345678909"],
    ])
    guard let process = response["process"] as? [String: Any] else { return }
    // process is { id, webAppToken, ... }: open the native SDK with process["webAppToken"].
} catch let error as UnicoError {
    print(error.status, error.body)
}
```

`privateKey` is a `SecKey`. Security.framework reads RSA keys as PKCS#1, and Unico's `.pem` is PKCS#8, so [`settings/Settings.swift`](settings/Settings.swift) unwraps it in `parsePrivateKey`.

`accessToken()` returns the cached access token, or asks for a new one: call it to check the credentials without calling the API, as setup step 1 does. A token proves the account, tenant and key, not which flows the account has. `getProcess(id)` returns `{ "process": { id, state, result, ... } }`. `getSelfie(id)` and `getEvidenceSet(id)` return `{ fileContents, contentType }`, with the file in base64. Every non-2xx answer from Unico throws a `UnicoError` with the status and body as returned. A malformed process id throws an `InvalidInputError` before anything is sent. Network failures throw `URLError`.

## Code

[`AGENTS.md`](AGENTS.md) explains where each piece is, how the native SDK opens and returns, and what to change when you build your own app.
