# AGENTS.md · iOS

Rules for agents reading or porting the iOS reference app. The repo-wide rules in [`../AGENTS.md`](../AGENTS.md) apply too. `CLAUDE.md` is a symlink to this file.

## What it is

One SwiftUI app with a `NavigationStack`. It creates the process, opens the journey with Unico's native SDK and shows the result. How to run it is in [`README.md`](README.md#run).

**Demo mode.** The app has no server, so it takes the service account on the Connect screen and calls Unico from the device. That is for demonstration only: the Connect screen says so where the key is entered, and the code is marked `DEMO ONLY`. In production, your server holds the key, creates the process and sends the app only the `webAppToken`. The server side of this repo is [`../web/api/unico.js`](../web/api/unico.js).

## Where each piece is

| Path | What it does | How to use it |
|---|---|---|
| `api/Unico.swift` | Unico client: JWT signed with `SecKeyCreateSignature` (RS256), access token (public, so Connect can verify credentials), Create Process, Get Process, selfie, evidence set. Foundation and Security only, an `actor`, `UnicoError` with status and body | **Demo only on a device.** Reference for the calls and error handling; in production this runs on your server (compare `web/api/unico.js`) |
| `settings/` | Connect screen and storage: unique account name, tenant ID (the `iss` is built from them), `.pem` imported from Files or pasted, SDK key, Bundle Identifier, and the hosts under API endpoints (UAT prefilled). Verify connection asks for a token before saving. The `.pem` goes to the Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; `parsePrivateKey` turns it into a `SecKey` | **Demo only.** Don't carry it over: your app holds no service account key. Only the SDK key belongs in a real app |
| `flows/Flows.swift` | Builds the Create Process body from form values: the flow typed by name, the person, and the extra fields switched on in Customize | Reference for mapping your data to the Create Process body |
| `flows/FormScreen.swift` | Run a flow: the flow typed by name, the document, a preview of the request, the Customize sheet, and the error screen with the response as returned | Reference for your own screens |
| `journey/native-sdk/` | Asks for the camera, opens the SDK with the `webAppToken`, returns the `processId` from `onSuccess`, and sends the user to Settings when the camera is denied. Behind the camera, the page shows the journey in progress, then why it stopped. Imports nothing from the other folders | Reference for opening the journey on iOS |
| `result/` | One `GET` for the process and one for the selfie. A heading names the result in words (`PROCESS_RESULT_OK` as Success, in `Verdict.swift`) and the JSON is shown raw; the evidence set fetched when opened and drawn with PDFKit | Reference for the calls after `onSuccess` |
| `app/` | The `App` and navigation, `Ui.swift` (colors and shared pieces of the screens), `Info.plist` and `Assets.xcassets` (the launch screen logo) | Glue; the navigation and look are yours |
| `test/` | Swift Testing tests for `api/` against a local fake of Unico (a `URLProtocol`), for `flows/Flows.swift` and for `result/Verdict.swift` | Reference for testing your client |
| `project.yml`, `Package.swift` | `xcodegen generate` builds the app project from `project.yml`. `Package.swift` exists only so `swift test` runs the tests on a Mac | Build files |

## The flow, end to end

1. The form builds the body with `callbackUri` set to `/`, which the docs ask for when the native SDK handles the return in-app.
2. `Unico.createProcess` returns `{ process }`. The app takes `process.webAppToken`.
3. `journey/native-sdk/` checks the camera with `AVCaptureDevice`, builds `AcessoBioManager` with a view controller, its delegate and the environment, calls `prepareSelfieCamera` with the SDK key, and in `onCameraReady` calls `open(_:webAppToken:)`.
4. When the journey ends, the SDK calls `onSuccess(SuccessResult)`. The app dismisses the SDK's screen, reads `processId` and moves to the result.
5. `result/` makes one `GET` for the process and one for the selfie. The evidence set is one `GET` when the user opens it. No polling and no webhook.

## Building your own integration

Treat this app as a reference, not as code to copy file by file. Read how each piece works, then write it the way your app does things.

- Move `api/` to your server. The device asks your server for a process and gets back the `webAppToken` (and the `id`, if you want to correlate). After `onSuccess`, the device tells your server, which makes the one `GET`. The key never ships in the app.
- The journey runs only in the native SDK. Don't open `userRedirectUrl` in a `WKWebView`, `SFSafariViewController`, `ASWebAuthenticationSession` or Safari.
- On UIKit, the same steps live in a `UIViewController`: it is the SDK's `viewController`, it can be the delegate, and it presents the journey. `journey/native-sdk/` hosts a plain `UIViewController` behind the SwiftUI view for that.
- The SDK key from Unico's Onboarding team is linked to your Bundle Identifier and Team ID. Set both in `project.yml`, or the SDK refuses to start.
- The SDK environment must match the hosts the process was created on: `.UAT` for UAT, `.PROD` for production. The SDK defaults to `.PROD`, so set it.
- Add `NSCameraUsageDescription` to `Info.plist`, ask for the camera before opening the SDK, and give the user a way to Settings when the permission is denied (error `73706`). iOS asks only once.
- Keep the capture in portrait: the SDK cancels in landscape (`73708`) or upside down (`73709`). This app is portrait-only.
- The SDK doesn't run on simulators (error `73006`). Use an iPhone.
- The SDK may call its delegates off the main thread. Copy the values you need and go back to the main thread before touching UI.
- The SDK leaves its screen open after some endings ([Known issues](https://developer.unico.io/developers/sdks-and-tools/ios/resources/known-issues)). Dismiss what it presented when a callback ends the journey.
- `onSuccessSelfie` belongs to the Dual API. The protocol requires it; a Unico API journey ignores its result.
- SwiftUI runs `onAppear` and `.task` again when a screen comes back into view. Guard the journey and the result `GET` so each runs once.

## Docs behind each piece

- SDK install, init, journey and callbacks: [iOS SDK](https://developer.unico.io/developers/sdks-and-tools/ios/requirements), [User Journeys](https://developer.unico.io/developers/sdks-and-tools/ios/capture-flow/user-journeys), [Receiving the result](https://developer.unico.io/developers/sdks-and-tools/ios/capture-flow/receiving-the-result), [Error handling](https://developer.unico.io/developers/sdks-and-tools/ios/error-handling)
- Token: [Authentication](https://developer.unico.io/developers/start/authentication), hosts: [Environments](https://developer.unico.io/developers/start/environments)
- Calls: [Create Process](https://developer.unico.io/developers/api-reference/post-processes), [Get Process](https://developer.unico.io/developers/api-reference/get-process), [Get Selfie](https://developer.unico.io/developers/api-reference/get-selfie), [Get Evidence Set](https://developer.unico.io/developers/api-reference/get-evidence-set)
