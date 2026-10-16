// Native SDK: https://developer.unico.io/developers/sdks-and-tools/flutter/capture-flow/user-journeys
// Opens Unico's journey with the process's webAppToken through the official unico_check plugin and hands back the
// processId from onSuccess. The journey always runs in the SDK: never in a WebView, Custom Tabs or the system browser.
// Self-contained: the mode imports nothing from the other folders. It takes plain values and returns a processId.
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unico_check/unico_check.dart';

// https://developer.unico.io/developers/sdks-and-tools/flutter/error-handling
const _cameraPermissionDenied = 73002;

enum _State { opening, cameraDenied, ended }

// `sdkKey` comes from Unico's Onboarding team, linked to `bundleIdentifier` (the Android application ID or
// the iOS bundle ID). `environment` must match the hosts the process was created on: UnicoEnvironment.UAT or .PROD.
class NativeSdkJourney extends StatefulWidget {
  const NativeSdkJourney({
    super.key,
    required this.webAppToken,
    required this.sdkKey,
    required this.bundleIdentifier,
    required this.environment,
    required this.onFinished,
    required this.onBack,
  });

  final String webAppToken;
  final String sdkKey;
  final String bundleIdentifier;
  final UnicoEnvironment environment;
  final ValueChanged<String> onFinished;
  final VoidCallback onBack;

  @override
  State<NativeSdkJourney> createState() => _NativeSdkJourneyState();
}

// UnicoListener gets session events; UnicoSdks gets the journey's result. The docs put onSuccess on UnicoSelfie,
// but in unico_check it lives on UnicoSdks; UnicoSelfie and onSuccessSelfie belong to the Dual API.
class _NativeSdkJourneyState extends State<NativeSdkJourney> implements UnicoListener, UnicoSdks {
  _State state = _State.opening;
  String message = '';

  // https://developer.unico.io/developers/sdks-and-tools/flutter/initialization
  // The same SDK key goes in both configs because this app reads it from Settings on the device it runs on.
  // Yours has one key per platform.
  late final UnicoCheck unicoCheck = UnicoCheck(
    listener: this,
    unicoConfigAndroid: UnicoConfig(getBundleIdentifier: widget.bundleIdentifier, getHostKey: widget.sdkKey),
    unicoConfigIos: UnicoConfig(getBundleIdentifier: widget.bundleIdentifier, getHostKey: widget.sdkKey),
  )..setEnvironment(unicoEnvironment: widget.environment);

  void end(String text) {
    if (!mounted) return;
    setState(() {
      state = _State.ended;
      message = text;
    });
  }

  String describe(UnicoError error) => 'SDK error ${error.code}: ${error.description}';

  // The app asks for the camera before opening the SDK. On Android the plugin asks too when it's missing,
  // but then closes without a callback, so the journey would seem to do nothing.
  Future<void> start() async {
    setState(() => state = _State.opening);
    final status = await Permission.camera.request();
    if (!mounted) return;
    if (!status.isGranted) {
      setState(() => state = _State.cameraDenied);
      return;
    }
    unicoCheck.build().openCameraSelfie(listener: this, webAppToken: widget.webAppToken);
  }

  @override
  void initState() {
    super.initState();
    start();
  }

  // https://developer.unico.io/developers/sdks-and-tools/flutter/capture-flow/receiving-the-result
  @override
  void onSuccess(SuccessResult result) {
    final processId = result.processId;
    if (processId == null) return end('The SDK finished without a processId.');
    if (mounted) widget.onFinished(processId);
  }

  @override
  void onErrorSelfie(UnicoError error) => end(describe(error));

  @override
  void onErrorUnico(UnicoError error) {
    if (error.code == _cameraPermissionDenied) {
      if (mounted) setState(() => state = _State.cameraDenied);
    } else {
      end(describe(error));
    }
  }

  @override
  void onUserClosedCameraManually() => end('The journey was closed before it finished.');

  @override
  void onSystemClosedCameraTimeoutSession() => end('The capture session timed out.');

  // The SDK switches to manual capture and the journey goes on.
  @override
  void onSystemChangedTypeCameraTimeoutFaceInference() {}

  @override
  Widget build(BuildContext context) {
    final title = Theme.of(context).textTheme.headlineSmall;
    final children = switch (state) {
      _State.opening => [Text('Opening the journey', style: title), const CircularProgressIndicator()],
      // Once the user denies the camera for good, the OS stops asking, so the way back is the app's settings.
      _State.cameraDenied => [
        Text('Camera access needed', style: title),
        const Text('The journey takes a selfie. Allow the camera in Settings, then try again.'),
        FilledButton(onPressed: openAppSettings, child: const Text('Open Settings')),
        OutlinedButton(onPressed: start, child: const Text('Try again')),
        OutlinedButton(onPressed: widget.onBack, child: const Text('Back')),
      ],
      _State.ended => [
        Text('Journey not finished', style: title),
        SelectableText(message),
        OutlinedButton(onPressed: widget.onBack, child: const Text('Back')),
      ],
    };
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, spacing: 12, children: children),
    );
  }
}
