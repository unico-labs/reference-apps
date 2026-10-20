// DEMO ONLY: CredentialsScreen takes the service account key on the device. In production your server holds it.
// The SDK key is the one value here a real app ships, in its own config rather than typed in.
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/unico.dart';
import '../ui.dart';
import 'settings.dart';

extension Environment on Settings {
  String get environment => hosts == Hosts.prod ? 'PROD' : 'UAT';
}

const _authenticationGuide = 'https://developer.unico.io/developers/start/authentication';
const _flutterSetup = 'https://developer.unico.io/developers/sdks-and-tools/flutter/installation/specific-setup';

class _Link extends StatelessWidget {
  const _Link(this.label, this.url);

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton(
      style: TextButton.styleFrom(padding: EdgeInsets.zero),
      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}

// "Step 1 of 2" over a bar of two segments.
class _Progress extends StatelessWidget {
  const _Progress(this.label, {required this.filled});

  final String label;
  final int filled;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: 8,
    children: [
      Text(
        label,
        style: const TextStyle(color: muted, fontSize: 12, fontWeight: FontWeight.bold),
      ),
      Row(
        spacing: 6,
        children: [
          for (var i = 0; i < 2; i++)
            Expanded(
              child: Container(
                height: 4,
                decoration: BoxDecoration(color: i < filled ? accent : line, borderRadius: BorderRadius.circular(2)),
              ),
            ),
        ],
      ),
    ],
  );
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w800),
      ),
      Hint(subtitle),
    ],
  );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, required this.onStart});

  final VoidCallback onStart;

  static const _steps = [
    ('Set up this app', 'Add your API credentials and SDK settings once.'),
    ('Run a flow', "Type the flow name and the person's document."),
    ('Read the result', 'See the response, the selfie and the evidence set.'),
  ];

  @override
  Widget build(BuildContext context) => Screen(
    content: [
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          Text(
            'Unico reference app',
            style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          Text(
            'See how a Unico integration works',
            style: TextStyle(color: ink, fontSize: 26, fontWeight: FontWeight.w800),
          ),
          Text(
            'Run a real flow in UAT. You see the request a backend would send and the result that comes back.',
            style: TextStyle(color: ink, fontSize: 15),
          ),
        ],
      ),
      const Lab('How it works'),
      for (final (i, (title, body)) in _steps.indexed)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: extraGround,
              child: Text(
                '${i + 1}',
                style: const TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: ink, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  Hint(body),
                ],
              ),
            ),
          ],
        ),
      const Lab("What you'll need"),
      const Panel(
        children: [
          Text(
            'API credentials',
            style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          Text(
            'Service account, Tenant ID and private key. They let this app create the process when you start a test.',
            style: TextStyle(color: ink),
          ),
          Hint('In your own app this runs on your backend.'),
          _Link('Authentication guide ↗', _authenticationGuide),
        ],
      ),
      const Panel(
        children: [
          Text(
            'SDK settings',
            style: TextStyle(color: ink, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          Text('SDK key and app ID. They let the camera experience open.', style: TextStyle(color: ink)),
          Hint("Unico issues the SDK key for your app's bundle ID (iOS) or application ID (Android)."),
          _Link('Flutter setup ↗', _flutterSetup),
        ],
      ),
    ],
    dock: [FilledButton(onPressed: onStart, child: const Text('Get started'))],
  );
}

// Step 1. `onVerify` asks Unico for an access token with these settings. It returns an error to show, or null when
// the token came back and the next step opened.
class CredentialsScreen extends StatefulWidget {
  const CredentialsScreen({super.key, required this.initial, required this.onVerify});

  final Settings initial;
  final Future<String?> Function(Settings) onVerify;

  @override
  State<CredentialsScreen> createState() => _CredentialsScreenState();
}

class _CredentialsScreenState extends State<CredentialsScreen> {
  late Settings settings = widget.initial;
  // The stored key is never shown again. Leave the field empty to keep it.
  final pem = TextEditingController();
  String? error;
  bool sending = false;
  bool advanced = false;

  // A .pem has no registered type on either platform, so the picker accepts any file and the key check decides.
  Future<void> importPem() async {
    final file = await openFile();
    if (file != null) pem.text = await file.readAsString();
  }

  Future<void> verify() async {
    final next = pem.text.trim().isEmpty ? settings : settings.copyWith(privateKeyPem: pem.text.trim());
    String? problem;
    if (!next.hasCredentials) {
      problem = 'Fill in every field and add the private key.';
    } else {
      try {
        parsePrivateKey(next.privateKeyPem);
      } on FormatException catch (e) {
        problem = e.message;
      }
    }
    setState(() {
      error = problem;
      sending = problem == null;
    });
    if (problem != null) return;
    final result = await widget.onVerify(next);
    if (!mounted) return;
    setState(() {
      error = result;
      sending = false;
    });
  }

  @override
  void dispose() {
    pem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Screen(
    content: [
      const _Progress('Step 1 of 2', filled: 1),
      const _Title('API credentials', 'Used to create the process when you start a test.'),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(color: warnGround, borderRadius: BorderRadius.circular(10)),
        child: const Text(
          'Demo only. Credentials stay on this device. In your own app, keep them on your backend.',
          style: TextStyle(color: warnInk, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
      Field(
        label: 'Service account',
        hint: 'Your unique account name',
        initial: settings.account,
        onChanged: (v) => setState(() => settings = settings.copyWith(account: v.trim())),
      ),
      // The JWT iss is built from these two: https://developer.unico.io/developers/start/authentication
      Field(
        label: 'Tenant ID',
        hint: settings.account.isEmpty || settings.tenant.isEmpty
            ? 'iss: <account_name>@<tenant_id>.iam.acesso.io'
            : 'iss: ${settings.serviceAccount}',
        initial: settings.tenant,
        onChanged: (v) => setState(() => settings = settings.copyWith(tenant: v.trim())),
      ),
      Field(
        label: 'Private key (.pem)',
        placeholder: widget.initial.privateKeyPem.isEmpty
            ? '-----BEGIN PRIVATE KEY-----'
            : 'Key added. Paste or import to replace it',
        hint: 'Paste it or import the file. Stored in the Android Keystore or the iOS Keychain.',
        mono: true,
        lines: 3,
        controller: pem,
      ),
      OutlinedButton(onPressed: importPem, child: const Text('Import .pem file')),
      const Hint(
        'Unico provides all three when it creates your service account. '
        'Never ship the private key inside a mobile app.',
      ),
      const _Link('Authentication guide ↗', _authenticationGuide),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
          onPressed: () => setState(() => advanced = !advanced),
          child: Text(
            advanced ? 'Hide API endpoints' : 'API endpoints (advanced)',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      // https://developer.unico.io/developers/start/environments
      if (advanced) ...[
        Field(
          label: 'Identity host',
          initial: settings.identityHost,
          onChanged: (v) => setState(() => settings = settings.copyWith(identityHost: v.trim())),
        ),
        Field(
          label: 'API host',
          initial: settings.apiHost,
          onChanged: (v) => setState(() => settings = settings.copyWith(apiHost: v.trim())),
        ),
      ],
      if (error != null) Panel(children: [CodeBlock(error!)]),
    ],
    dock: [
      FilledButton(onPressed: sending ? null : verify, child: Text(sending ? 'Verifying…' : 'Verify credentials')),
    ],
  );
}

class ConnectedScreen extends StatelessWidget {
  const ConnectedScreen({super.key, required this.settings, required this.onContinue});

  final Settings settings;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Screen(
    content: [
      const _Progress('Step 1 of 2 · done', filled: 1),
      Heading(
        icon: Icons.check,
        ink: okInk,
        ground: okGround,
        title: 'Connected to the API',
        subtitle: 'Unico ${settings.environment} accepted your credentials.',
      ),
      Panel(
        children: [
          KeyValue('Service account', settings.account),
          KeyValue('Tenant ID', settings.tenant),
          KeyValue('Environment', settings.environment),
        ],
      ),
      const Text(
        'One more step: the SDK settings, so the camera experience can open.',
        style: TextStyle(color: ink, fontSize: 15),
      ),
    ],
    dock: [FilledButton(onPressed: onContinue, child: const Text('Continue to SDK settings'))],
  );
}

// Step 2. `onSave` saves the settings from both steps and returns an error to show when saving fails, or null.
class SdkSettingsScreen extends StatefulWidget {
  const SdkSettingsScreen({super.key, required this.initial, required this.onSave});

  final Settings initial;
  final Future<String?> Function(Settings) onSave;

  @override
  State<SdkSettingsScreen> createState() => _SdkSettingsScreenState();
}

class _SdkSettingsScreenState extends State<SdkSettingsScreen> {
  late String sdkKey = widget.initial.sdkKey;
  String? error;

  Future<void> save() async {
    final next = widget.initial.copyWith(sdkKey: sdkKey);
    if (!next.isComplete) {
      setState(() => error = sdkKey.isEmpty ? 'Add the SDK key.' : 'Add the API credentials first.');
      return;
    }
    final result = await widget.onSave(next);
    if (mounted) setState(() => error = result);
  }

  @override
  Widget build(BuildContext context) => Screen(
    content: [
      const _Progress('Step 2 of 2', filled: 2),
      const _Title('SDK settings', 'Used to open the camera experience.'),
      // https://developer.unico.io/developers/sdks-and-tools/flutter/installation/specific-setup
      Field(
        label: 'SDK key',
        placeholder: 'Paste the key Unico issued',
        initial: sdkKey,
        onChanged: (v) => setState(() => sdkKey = v.trim()),
      ),
      const Field(
        label: 'App ID',
        hint: 'Bundle ID (iOS) or application ID (Android) of this app. The SDK key must be issued for it.',
        initial: buildBundleIdentifier,
        readOnly: true,
      ),
      const Hint(
        "Ask Unico's Onboarding team for an SDK key linked to your app ID. We don't check it here. If the camera "
        "doesn't open, review the key and the app ID.",
      ),
      const _Link('Flutter setup ↗', _flutterSetup),
      if (error != null) Panel(children: [CodeBlock(error!)]),
    ],
    dock: [FilledButton(onPressed: save, child: const Text('Save and continue'))],
  );
}
