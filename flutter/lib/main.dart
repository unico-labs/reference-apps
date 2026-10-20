// Navigation and glue. Screens: Welcome and setup (settings), Run a flow, journey (native SDK), result, evidence set.
// Everything Unico-specific lives in the other folders; this file wires them together.
import 'package:flutter/material.dart';
import 'package:unico_check/unico_check.dart' show UnicoEnvironment;

import 'api/unico.dart';
import 'flows/form_screen.dart';
import 'journey/native-sdk/native_sdk_journey.dart';
import 'result/evidence_set_screen.dart';
import 'result/result_screen.dart';
import 'settings/settings.dart';
import 'settings/settings_screen.dart';
import 'ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsStore().load();
  runApp(ReferenceApp(settings: settings));
}

class ReferenceApp extends StatefulWidget {
  const ReferenceApp({super.key, required this.settings});

  final Settings settings;

  @override
  State<ReferenceApp> createState() => _ReferenceAppState();
}

class _ReferenceAppState extends State<ReferenceApp> {
  final nav = GlobalKey<NavigatorState>();
  late Settings settings = widget.settings;
  // DEMO ONLY: the app builds the Unico client on the device. In production, your server does.
  late Unico? unico = _client(settings);
  // The last journey finished here, offered as the reference for a step-up.
  String? lastProcessId;

  static Unico? _client(Settings s) => s.isComplete
      ? Unico(serviceAccount: s.serviceAccount, privateKey: parsePrivateKey(s.privateKeyPem), hosts: s.hosts)
      : null;

  // The SDK environment follows the hosts in setup: PROD hosts open the PROD journey, anything else UAT.
  UnicoEnvironment get environment => settings.hosts == Hosts.prod ? UnicoEnvironment.PROD : UnicoEnvironment.UAT;

  NavigatorState get navigator => nav.currentState!;

  // The top bar: the screen's title and, once set up, a pill with the environment and account that opens
  // API credentials.
  Route<void> page(String title, Widget body, {bool pill = true}) => MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (pill && unico != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: InkWell(
                onTap: () => navigator.push(credentialsPage()),
                borderRadius: BorderRadius.circular(999),
                child: Pill('✓ ${settings.environment} · ${settings.account}'),
              ),
            ),
        ],
      ),
      body: body,
    ),
  );

  // Welcome has no top bar, so it doesn't go through page().
  Route<void> welcomePage() => MaterialPageRoute(
    builder: (_) => Scaffold(
      body: SafeArea(bottom: false, child: WelcomeScreen(onStart: () => navigator.push(credentialsPage()))),
    ),
  );

  // The setup steps keep what was typed in memory, passed from screen to screen, until SDK settings saves it.
  Route<void> credentialsPage() => page(
    'Set up this app',
    CredentialsScreen(
      initial: settings,
      onVerify: (next) async {
        // A token proves the account, tenant and key; it says nothing about the account's flows.
        try {
          await Unico(
            serviceAccount: next.serviceAccount,
            privateKey: parsePrivateKey(next.privateKeyPem),
            hosts: next.hosts,
          ).accessToken();
        } on Object catch (e) {
          return describe(e);
        }
        navigator.push(connectedPage(next));
        return null;
      },
    ),
    pill: false,
  );

  Route<void> connectedPage(Settings next) => page(
    'Set up this app',
    ConnectedScreen(settings: next, onContinue: () => navigator.push(sdkSettingsPage(next))),
    pill: false,
  );

  Route<void> sdkSettingsPage(Settings next) => page(
    'Set up this app',
    SdkSettingsScreen(
      initial: next,
      onSave: (saved) async {
        try {
          await SettingsStore().save(saved);
        } on Object catch (e) {
          return describe(e);
        }
        setState(() {
          settings = saved;
          unico = _client(saved);
        });
        navigator.pushAndRemoveUntil(formPage(), (_) => false);
        return null;
      },
    ),
    pill: false,
  );

  Route<void> formPage({bool stepUp = false}) => page(
    'Run a flow',
    FormScreen(
      reference: lastProcessId,
      stepUp: stepUp,
      onSubmit: (body) async {
        try {
          final process = (await unico!.createProcess(body))['process'] as Map<String, dynamic>;
          navigator.push(
            journeyPage(process['webAppToken'] as String, body['flow'] as String, process['id'] as String),
          );
          return null;
        } on Object catch (e) {
          return describe(e);
        }
      },
    ),
  );

  Route<void> journeyPage(String webAppToken, String flow, String processId) => page(
    'Run a flow',
    NativeSdkJourney(
      webAppToken: webAppToken,
      flow: flow,
      processId: processId,
      sdkKey: settings.sdkKey,
      bundleIdentifier: buildBundleIdentifier,
      environment: environment,
      onFinished: (processId) {
        // Only a finished journey is offered as the reference for a step-up.
        lastProcessId = processId;
        // Replaces the journey, so Back from the result goes to the form.
        navigator.pushAndRemoveUntil(resultPage(processId), (r) => r.isFirst);
      },
      onBack: () => navigator.pop(),
    ),
  );

  Route<void> resultPage(String processId) => page(
    'Result',
    ResultScreen(
      unico: unico!,
      processId: processId,
      onEvidenceSet: () => navigator.push(page('Evidence set', EvidenceSetScreen(unico: unico!, processId: processId))),
      onStepUp: () => navigator.pushAndRemoveUntil(formPage(stepUp: true), (_) => false),
      onDone: () => navigator.pushAndRemoveUntil(formPage(), (_) => false),
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Unico Reference App',
    theme: referenceTheme(),
    navigatorKey: nav,
    // Every screen is pushed as a route built here, so no route is looked up by name. MaterialApp still asks for
    // a way to build one when it gets a navigatorKey without a home.
    onGenerateRoute: (_) => null,
    // Incomplete settings open Welcome first.
    onGenerateInitialRoutes: (_) => [unico == null ? welcomePage() : formPage()],
  );
}
