# AGENTS.md · Flutter

Rules for agents reading or porting the Flutter reference app. The repo-wide rules in [`../AGENTS.md`](../AGENTS.md) apply too. `CLAUDE.md` is a symlink to this file.

## What it is

One Flutter app with Material 3 and a plain `Navigator`. It creates the process, opens the journey with Unico's official Flutter plugin, [`unico_check`](https://pub.dev/packages/unico_check), and shows the result. How to run it is in [`README.md`](README.md#run).

**Demo mode.** The app has no server, so it takes the service account on the Connect screen and calls Unico from the device. That is for demonstration only: the Connect screen says so where the key is entered, and the code is marked `DEMO ONLY`. In production, your server holds the key, creates the process and sends the app only the `webAppToken`. The server side of this repo is [`../web/api/unico.js`](../web/api/unico.js).

**Layout.** The Dart sources live under `lib/`, in the same folders as every other app in this repo, and the entry point is `lib/main.dart`. The paths below are relative to `lib/`.

## Where each piece is

| Path | What it does | How to use it |
|---|---|---|
| `api/unico.dart` | Unico client: JWT, access token, Create Process, Get Process, selfie, evidence set. `package:http` and `dart_jsonwebtoken`, no Flutter. `UnicoError` with status and body | **Demo only on a device.** Reference for the calls and error handling; in production this runs on your server (compare `web/api/unico.js`) |
| `settings/` | Connect screen and storage: unique account name, tenant ID (the `iss` is built from them), `.pem` imported or pasted, SDK key, bundle ID / application ID, and the hosts under API endpoints (UAT prefilled). Verify connection asks for a token before saving. Everything goes to `flutter_secure_storage`: Android Keystore, iOS Keychain with "this device only". `allowBackup="false"` on Android | **Demo only.** Don't carry it over: your app holds no service account key. Only the SDK key belongs in a real app |
| `flows/flows.dart` | Builds the Create Process body from form values: the flow typed by name, the person, and the extra fields switched on in Customize | Reference for mapping your data to the Create Process body |
| `flows/form_screen.dart` | Run a flow: the flow typed by name, the document, a preview of the request, the Customize sheet, and the error screen with the response as returned | Reference for your own screens |
| `journey/native-sdk/` | Asks for the camera, opens `unico_check` with the `webAppToken`, returns the `processId` from `onSuccess`, and sends the user to Settings when the camera is denied. Behind the camera, the page shows the journey in progress, then why it stopped. Imports nothing from the other folders | Reference for opening the journey in Flutter |
| `result/` | One `GET` for the process and one for the selfie. A heading names the result in words (`PROCESS_RESULT_OK` as Success, in `verdict.dart`) and the JSON is shown raw; the evidence set fetched when opened and drawn in-app with `pdfx` | Reference for the calls after `onSuccess` |
| `main.dart`, `ui.dart` | Navigation and the top bar; the colors and shared pieces of the screens | Glue; the navigation and look are yours |
| `android/`, `ios/` | Platform projects: app name, launch screen logo, application ID, camera permission, Unico's Maven repository, ProGuard rules, `allowBackup="false"` | Compare with your own platform setup |
| `../test/` | Dart VM tests for `api/` against a local fake of Unico, for `flows/flows.dart` and `result/verdict.dart`, and a widget test that the app opens | Reference for testing your client |

## The flow, end to end

1. The form builds the body with `callbackUri` set to `/`, which the docs ask for when the native SDK handles the return in-app.
2. `Unico.createProcess` returns `{ process }`. The app takes `process['webAppToken']`.
3. `journey/native-sdk/` asks for the camera with `permission_handler`, builds `UnicoCheck` with a `UnicoConfig` per platform (bundle ID and SDK key) and the environment, and calls `build().openCameraSelfie(listener: this, webAppToken: ...)`.
4. When the journey ends, the plugin calls `onSuccess(SuccessResult)` on the `UnicoSdks` listener. The app reads `processId` and moves to the result.
5. `result/` makes one `GET` for the process and one for the selfie. The evidence set is one `GET` when the user opens it. No polling and no webhook.

## Building your own integration

Treat this app as a reference, not as code to copy file by file. Read how each piece works, then write it the way your app does things.

- Move `api/` to your server. The app asks your server for a process and gets back the `webAppToken` (and the `id`, if you want to correlate). After `onSuccess`, the app tells your server, which makes the one `GET`. The key never ships in the app.
- The journey runs only in the native SDK, through `unico_check`. Don't open `userRedirectUrl` in a WebView, Custom Tabs or the browser, and don't bridge the native Android or iOS SDKs yourself: the docs support only the official plugin.
- The SDK key from Unico's Onboarding team is linked to your app's identifiers: package name and SHA-256 on Android, bundle ID and Team ID on iOS. Each platform gets its own key in its own `UnicoConfig`; this demo reads one key from Connect and passes it to both. A key linked to another ID makes the SDK refuse to start (error `73303`).
- The SDK environment must match the hosts the process was created on: `UnicoEnvironment.UAT` for UAT, `UnicoEnvironment.PROD` for production. The plugin defaults to `PROD`.
- In `unico_check`, `onSuccess` lives on `UnicoSdks`, not on `UnicoSelfie` as the docs show. `UnicoSelfie` and `onSuccessSelfie` belong to the Dual API. The error fields are `error.code` and `error.description`.
- Ask for the camera before opening the SDK. On Android the plugin asks by itself when the permission is missing, but then closes without calling any listener. Give the user a way to Settings when the permission is denied for good (error `73002`).
- The SDK doesn't run on emulators or simulators (error `73006`). Use a physical device.
- Release builds on Android are shrunk, so keep the SDK's ProGuard rules from [Specific setup](https://developer.unico.io/developers/sdks-and-tools/flutter/installation/specific-setup) (`android/app/proguard-rules.pro` here).
- On iOS the plugin comes through CocoaPods. Before submitting to the App Store, apply the bitcode workaround in [Known issues](https://developer.unico.io/developers/sdks-and-tools/flutter/resources/known-issues).

## Docs behind each piece

- Plugin install, init, journey and callbacks: [Flutter SDK](https://developer.unico.io/developers/sdks-and-tools/flutter/requirements), [Installation](https://developer.unico.io/developers/sdks-and-tools/flutter/installation), [User Journeys](https://developer.unico.io/developers/sdks-and-tools/flutter/capture-flow/user-journeys), [Receiving the result](https://developer.unico.io/developers/sdks-and-tools/flutter/capture-flow/receiving-the-result), [Error handling](https://developer.unico.io/developers/sdks-and-tools/flutter/error-handling)
- Token: [Authentication](https://developer.unico.io/developers/start/authentication), hosts: [Environments](https://developer.unico.io/developers/start/environments)
- Calls: [Create Process](https://developer.unico.io/developers/api-reference/post-processes), [Get Process](https://developer.unico.io/developers/api-reference/get-process), [Get Selfie](https://developer.unico.io/developers/api-reference/get-selfie), [Get Evidence Set](https://developer.unico.io/developers/api-reference/get-evidence-set)
