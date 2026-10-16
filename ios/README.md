# iOS (SwiftUI, native SDK)

One SwiftUI app that creates a process, opens the journey with Unico's native SDK (`unicocheck-ios`, module `AcessoBio`) using the process's `webAppToken`, and shows the process JSON, the selfie and the evidence set PDF as returned.

> **Demo mode.** With no server, the app takes the service account key on a Settings screen and calls Unico from the device. Never do this in a real app: anything shipped to a device is public. In production your server holds the key and creates the process; see [`../web/`](../web/).

## Run

Requires a Mac with Xcode 16 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen), an **iPhone** (the SDK refuses simulators) and:

- UAT credentials: unique account name, tenant ID and `.pem` private key, as in [Authentication](https://developer.unico.io/developers/start/authentication). The app builds the JWT `iss` from the first two; See the root [README](../README.md#credentials);
- an SDK key from Unico's Onboarding team, linked to the app's Bundle Identifier and Team ID. Set `PRODUCT_BUNDLE_IDENTIFIER` and `DEVELOPMENT_TEAM` in [`project.yml`](project.yml) to the ones Unico linked.

The Xcode project is generated from `project.yml`, so it stays readable in review:

```sh
brew install xcodegen
xcodegen generate
open UnicoReference.xcodeproj
```

Xcode fetches the SDK through Swift Package Manager. Pick your iPhone and run.

On the device, fill in Settings: the hosts come filled in with UAT, then the unique account name, tenant ID, SDK key and the `.pem` key, imported from Files or pasted. Pick a flow, fill in the form with your own document and tap **Native SDK**.

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
    let process = response["process"] as! [String: Any]
    // process is { id, webAppToken, ... }: open the native SDK with process["webAppToken"].
} catch let error as UnicoError {
    print(error.status, error.body)
}
```

`privateKey` is a `SecKey`. Security.framework reads RSA keys as PKCS#1, and Unico's `.pem` is PKCS#8, so [`settings/Settings.swift`](settings/Settings.swift) unwraps it in `parsePrivateKey`.

`getProcess(id)` returns `{ "process": { id, state, result, ... } }`. `getSelfie(id)` and `getEvidenceSet(id)` return `{ fileContents, contentType }`, with the file in base64. Every non-2xx answer from Unico throws a `UnicoError` with the status and body as returned. A malformed process id throws an `InvalidInputError` before anything is sent. Network failures throw `URLError`.

## Code

[`AGENTS.md`](AGENTS.md) explains where each piece is, how the native SDK opens and returns, and what to change when you build your own app.
