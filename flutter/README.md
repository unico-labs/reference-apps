# Flutter (native SDK)

One Flutter app that creates a process, opens the journey with Unico's official Flutter plugin ([`unico_check`](https://pub.dev/packages/unico_check)) using the process's `webAppToken`, and shows the process JSON, the selfie and the evidence set PDF as returned.

> **Demo mode.** With no server, the app takes the service account key on the Connect screen and calls Unico from the device. Never do this in a real app: anything shipped to a device is public. In production your server holds the key and creates the process; see [`../web/`](../web/).

## Run

Requires the current stable Flutter, a **physical device** (the SDK refuses emulators and simulators) with its toolchain (Android SDK, or Xcode with CocoaPods for iOS) and:

- UAT credentials: unique account name, tenant ID and `.pem` private key, as in [Authentication](https://developer.unico.io/developers/start/authentication). The app builds the JWT `iss` from the first two; See the root [README](../README.md#credentials);
- an SDK key from Unico's Onboarding team, linked to the app's ID: package name and SHA-256 for Android, bundle ID and Team ID for iOS. This app uses `io.unico.reference` for both. Change it in [`android/app/build.gradle.kts`](android/app/build.gradle.kts) (`applicationId`), in the iOS project (`PRODUCT_BUNDLE_IDENTIFIER`) and in [`lib/settings/settings.dart`](lib/settings/settings.dart) (`buildBundleIdentifier`) to the one Unico linked. For a demo, Connect also lets you type another ID without rebuilding.

```sh
flutter pub get
flutter run
```

On the device, fill in Connect: the unique account name, tenant ID, the `.pem` key (imported from a file or pasted), the SDK key and the bundle ID / application ID. The hosts come filled in with UAT under API endpoints. **Verify connection** asks Unico for a token before saving. Then type the name of a flow your account has (see [Flows](https://developer.unico.io/developers/start/flows)), add your own document and tap **Start test**. Customize holds the optional and extra fields.

Building from Xcode.app instead of `flutter run`: `permission_handler` can't find `Info.plist` there and reports the camera as denied. Set `PERMISSION_HANDLER_INFO_PLIST` to the full path of `ios/Runner/Info.plist` (see the plugin's README).

## Test

The tests run on the Dart VM against a local fake of the Unico endpoints and need no credentials or device.

```sh
flutter test
```

## Using `lib/api/unico.dart` as a reference

[`lib/api/unico.dart`](lib/api/unico.dart) shows every Unico call this app makes, with `package:http` and `dart_jsonwebtoken` and no Flutter imports. It signs the JWT as in [Authentication](https://developer.unico.io/developers/start/authentication), caches the access token and renews it when 10 minutes or less remain. On a device it is demo code; on a Dart server it is the same client.

```dart
final unico = Unico(
  serviceAccount: 'my-account@abc123.iam.acesso.io',
  privateKey: RSAPrivateKey(pem),
  hosts: Hosts.uat,
);

try {
  final body = await unico.createProcess({
    'flow': 'idlive_r2',
    'callbackUri': '/', // the native SDK handles the return in-app
    'person': {'duiType': 'DUI_TYPE_BR_CPF', 'duiValue': '12345678909'},
  });
  final process = body['process'];
  // process is { id, webAppToken, ... }: open the native SDK with process['webAppToken'].
} on UnicoError catch (e) {
  print('${e.status} ${e.body}');
}
```

`accessToken()` returns the cached access token, or asks for a new one: call it to check the credentials without calling the API, as the Connect screen does. A token proves the account, tenant and key, not which flows the account has. `getProcess(id)` returns `{ "process": { id, state, result, ... } }`. `getSelfie(id)` and `getEvidenceSet(id)` return `{ fileContents, contentType }`, with the file in base64. Every non-2xx answer from Unico throws a `UnicoError` with the status and body as returned. A malformed process id throws an `InvalidInputError` before anything is sent. Network failures throw `http.ClientException`, and a call with no answer in 30 seconds throws `TimeoutException`.

## Code

[`AGENTS.md`](AGENTS.md) explains where each piece is, how the native SDK opens and returns, and what to change when you build your own app.
