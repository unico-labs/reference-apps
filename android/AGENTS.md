# AGENTS.md · Android

Rules for agents reading or porting the Android reference app. The repo-wide rules in [`../AGENTS.md`](../AGENTS.md) apply too. `CLAUDE.md` is a symlink to this file.

## What it is

One Jetpack Compose app, one activity, Navigation Compose. It creates the process, opens the journey with Unico's native SDK and shows the result. How to run it is in [`README.md`](README.md#run).

**Demo mode.** The app has no server, so it takes the service account on the Connect screen and calls Unico from the device. That is for demonstration only: the Connect screen says so where the key is entered, and the code is marked `DEMO ONLY`. In production, your server holds the key, creates the process and sends the app only the `webAppToken`. The server side of this repo is [`../web/api/unico.js`](../web/api/unico.js).

## Where each piece is

| Path | What it does | How to use it |
|---|---|---|
| `api/Unico.kt` | Unico client: JWT, access token (public, so Connect can verify credentials), Create Process, Get Process, selfie, evidence set. JDK and kotlinx.serialization only, `UnicoError` with status and body | **Demo only on a device.** Reference for the calls and error handling; in production this runs on your server (compare `web/api/unico.js`) |
| `settings/` | Connect screen and storage: unique account name, tenant ID (the `iss` is built from them), `.pem` imported or pasted, SDK key, application ID, and the hosts under API endpoints (UAT prefilled). Verify connection asks for a token before saving. The key is encrypted with an AES key kept in the Android Keystore; `allowBackup="false"` | **Demo only.** Don't carry it over: your app holds no service account key. Only the SDK key belongs in a real app |
| `flows/Flows.kt` | Builds the Create Process body from form values: the flow typed by name, the person, and the extra fields switched on in Customize | Reference for mapping your data to the Create Process body |
| `flows/FormScreen.kt` | Run a flow: the flow typed by name, the document, a preview of the request, the Customize sheet, and the error screen with the API's answer as returned | Reference for your own screens |
| `journey/native-sdk/` | Asks for the camera, opens the SDK with the `webAppToken`, returns the `processId` from `onSuccess`, and sends the user to Settings when the camera is denied. Behind the camera, the page shows the journey in progress, then why it stopped. Imports nothing from the other folders | Reference for opening the journey on Android |
| `result/` | One `GET` for the process and one for the selfie. A heading names the result in words (`PROCESS_RESULT_OK` as Success, in `Verdict.kt`) and the JSON is shown raw; the evidence set fetched when opened and drawn with `PdfRenderer` | Reference for the calls after `onSuccess` |
| `app/` | `MainActivity` (navigation, top bar), `Ui.kt` (colors and shared pieces of the screens) and the manifest | Glue; the navigation and look are yours |
| `test/` | JVM tests for `api/` against a local fake of Unico, for `flows/Flows.kt` and for `result/Verdict.kt` | Reference for testing your client |

## The flow, end to end

1. When the app loads, `MainActivity.onCreate` builds the SDK once with `NativeSdk` (`AcessoBio` with the environment and the camera mode: auto capture, smart frame, locale), as [Initialization](https://developer.unico.io/developers/sdks-and-tools/android/initialization) asks: its authentication takes a few seconds, so doing it on the button tap reads as lag.
2. The form builds the body with `callbackUri` set to `/`, which the docs ask for when the native SDK handles the return in-app.
3. `Unico.createProcess` returns `{ process }`. The app takes `process.webAppToken`.
4. `journey/native-sdk/` checks the `CAMERA` permission, calls `prepareCamera` on the SDK built at load with the SDK key, and in `onCameraReady` calls `open(listener, webAppToken)`.
5. When the journey ends, the SDK calls `onSuccess(SuccessResult)`. The app reads `processId` and moves to the result.
6. `result/` makes one `GET` for the process and one for the selfie. The evidence set is one `GET` when the user opens it. No polling and no webhook.

## Building your own integration

Treat this app as a reference, not as code to copy file by file. Read how each piece works, then write it the way your app does things.

- Move `api/` to your server. The device asks your server for a process and gets back the `webAppToken` (and the `id`, if you want to correlate). After `onSuccess`, the device tells your server, which makes the one `GET`. The key never ships in the APK.
- The journey runs only in the native SDK. Don't open `userRedirectUrl` in a WebView, Custom Tabs or the browser.
- The SDK key from Unico's Onboarding team is linked to your `applicationId`. Change `applicationId` in `build.gradle.kts` to one Unico linked, or the SDK refuses to start (error `73303`).
- The SDK environment must match the hosts the process was created on: `Environment.UAT` for UAT, `Environment.PROD` for production.
- Ask for the camera before opening the SDK, and give the user a way to Settings when the permission is denied for good (error `73002`).
- The SDK doesn't run on emulators (error `73006`). Use a physical device.
- The SDK can't be obfuscated. If you minify, add the keep rules in `app/proguard-rules.pro`, copied from [Specific setup](https://developer.unico.io/developers/sdks-and-tools/android/installation/specific-setup), to your own `proguard-rules.pro`. This app leaves minification off, so the file is there only as a reference.

## Docs behind each piece

- SDK install, init, journey and callbacks: [Android SDK](https://developer.unico.io/developers/sdks-and-tools/android/requirements), [User Journeys](https://developer.unico.io/developers/sdks-and-tools/android/capture-flow/user-journeys), [Error handling](https://developer.unico.io/developers/sdks-and-tools/android/error-handling)
- Token: [Authentication](https://developer.unico.io/developers/start/authentication), hosts: [Environments](https://developer.unico.io/developers/start/environments)
- Calls: [Create Process](https://developer.unico.io/developers/api-reference/post-processes), [Get Process](https://developer.unico.io/developers/api-reference/get-process), [Get Selfie](https://developer.unico.io/developers/api-reference/get-selfie), [Get Evidence Set](https://developer.unico.io/developers/api-reference/get-evidence-set)
