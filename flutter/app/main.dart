// Navigation and glue. Screens: settings, flows menu, form, journey (native SDK), result, evidence set.
// Everything Unico-specific lives in the other folders; this file wires them together.
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter/services.dart';
import 'package:unico_check/unico_check.dart' show UnicoEnvironment;

import '../api/unico.dart';
import '../flows/flows.dart';
import '../flows/flows_screen.dart';
import '../flows/form_screen.dart';
import '../journey/native-sdk/native_sdk_journey.dart';
import '../result/evidence_set_screen.dart';
import '../result/result_screen.dart';
import '../settings/settings.dart';
import '../settings/settings_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final flows = parseFlows(await rootBundle.loadString('flows/flows.json'));
  final settings = await SettingsStore().load();
  runApp(ReferenceApp(flows: flows, settings: settings));
}

class ReferenceApp extends StatefulWidget {
  const ReferenceApp({super.key, required this.flows, required this.settings});

  final List<Flow> flows;
  final Settings settings;

  @override
  State<ReferenceApp> createState() => _ReferenceAppState();
}

class _ReferenceAppState extends State<ReferenceApp> {
  final nav = GlobalKey<NavigatorState>();
  late Settings settings = widget.settings;
  // DEMO ONLY: the app builds the Unico client on the device. In production, your server does.
  late Unico? unico = _client(settings);

  static Unico? _client(Settings s) => s.isComplete
      ? Unico(serviceAccount: s.serviceAccount, privateKey: parsePrivateKey(s.privateKeyPem), hosts: s.hosts)
      : null;

  // The SDK environment follows the hosts in Settings: PROD hosts open the PROD journey, anything else UAT.
  UnicoEnvironment get environment => settings.hosts == Hosts.prod ? UnicoEnvironment.PROD : UnicoEnvironment.UAT;

  NavigatorState get navigator => nav.currentState!;

  Route<void> page(String title, Widget body, {bool settingsAction = true}) => MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (settingsAction)
            TextButton(onPressed: () => navigator.push(settingsPage()), child: const Text('Settings')),
        ],
      ),
      body: body,
    ),
  );

  Route<void> settingsPage() => page(
    'Settings',
    SettingsScreen(
      initial: settings,
      onSave: (saved) async {
        await SettingsStore().save(saved);
        setState(() {
          settings = saved;
          unico = _client(saved);
        });
        navigator.pushAndRemoveUntil(flowsPage(), (_) => false);
      },
    ),
    settingsAction: false,
  );

  Route<void> flowsPage() =>
      page('Unico API flows', FlowsScreen(flows: widget.flows, onPick: (flow) => navigator.push(formPage(flow))));

  Route<void> formPage(Flow flow) => page(
    flow.id,
    FormScreen(
      flow: flow,
      onSubmit: (body) async {
        try {
          final process = (await unico!.createProcess(body))['process'] as Map<String, dynamic>;
          navigator.push(journeyPage(process['webAppToken'] as String));
          return null;
        } on Object catch (e) {
          return describe(e);
        }
      },
    ),
  );

  Route<void> journeyPage(String webAppToken) => page(
    'Journey',
    NativeSdkJourney(
      webAppToken: webAppToken,
      sdkKey: settings.sdkKey,
      bundleIdentifier: settings.bundleIdentifier,
      environment: environment,
      // Replaces the form and the journey, so Back from the result goes to the flows menu.
      onFinished: (processId) => navigator.pushAndRemoveUntil(resultPage(processId), (r) => r.isFirst),
      onBack: () => navigator.pop(),
    ),
    settingsAction: false,
  );

  Route<void> resultPage(String processId) => page(
    'Result',
    ResultScreen(
      unico: unico!,
      processId: processId,
      onEvidenceSet: () => navigator.push(page('Evidence set', EvidenceSetScreen(unico: unico!, processId: processId))),
      onDone: () => navigator.popUntil((r) => r.isFirst),
    ),
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Unico API reference',
    theme: ThemeData(colorSchemeSeed: Colors.indigo),
    navigatorKey: nav,
    // Incomplete settings open Settings first.
    onGenerateInitialRoutes: (_) => [unico == null ? settingsPage() : flowsPage()],
    // Fixed on every screen: the credentials on this device are for demonstration only.
    builder: (context, child) => Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'Demo mode: the service account key is on this device. In production it lives only on your server.',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Expanded(child: child!),
          ],
        ),
      ),
    ),
  );
}
