// DEMO ONLY: the Connect screen. In production none of this is on the device; your server holds the credentials.
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../api/unico.dart';
import '../ui.dart';
import 'settings.dart';

extension Environment on Settings {
  String get environment => hosts == Hosts.prod ? 'PROD' : 'UAT';
}

// `onVerify` asks Unico for an access token with these settings. It returns an error to show, or null when the
// token came back; then the verified screen shows, and Continue saves the settings.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.initial, required this.onVerify, required this.onContinue});

  final Settings initial;
  final Future<String?> Function(Settings) onVerify;
  final ValueChanged<Settings> onContinue;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Settings settings = widget.initial;
  // The stored key is never shown again. Leave the field empty to keep it.
  final pem = TextEditingController();
  String? error;
  bool sending = false;
  bool advanced = false;
  Settings? verified;

  // A .pem has no registered type on either platform, so the picker accepts any file and the key check decides.
  Future<void> importPem() async {
    final file = await openFile();
    if (file != null) pem.text = await file.readAsString();
  }

  Future<void> verify() async {
    final next = pem.text.trim().isEmpty ? settings : settings.copyWith(privateKeyPem: pem.text.trim());
    String? problem;
    if (!next.isComplete) {
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
      if (result == null) verified = next;
    });
  }

  @override
  void dispose() {
    pem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = verified;
    if (done != null) {
      return Screen(
        content: [
          Heading(
            icon: Icons.check,
            ink: okInk,
            ground: okGround,
            title: 'Credentials verified',
            subtitle: 'We got a token from Unico ${done.environment}.',
          ),
          Panel(
            children: [
              KeyValue('Service account', done.account),
              KeyValue('Tenant ID', done.tenant),
              KeyValue('Environment', done.environment),
            ],
          ),
        ],
        dock: [FilledButton(onPressed: () => widget.onContinue(done), child: const Text('Continue'))],
      );
    }
    return Screen(
      content: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect your Unico account',
              style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            Hint('Done once. Used to sign every request.'),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: warnGround, borderRadius: BorderRadius.circular(10)),
          child: const Text(
            'Demo only. Credentials stay on this device; in your own app, keep them on your backend.',
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
              : 'Saved. Paste or import to replace it',
          hint: 'Paste it or import the file. Stored in the Android Keystore or the iOS Keychain.',
          mono: true,
          lines: 3,
          controller: pem,
          onChanged: (_) {},
        ),
        OutlinedButton(onPressed: importPem, child: const Text('Import .pem file')),
        // https://developer.unico.io/developers/sdks-and-tools/flutter/installation
        Field(
          label: 'SDK key',
          hint: 'Issued by Unico for the bundle ID / application ID below',
          initial: settings.sdkKey,
          onChanged: (v) => setState(() => settings = settings.copyWith(sdkKey: v.trim())),
        ),
        Field(
          label: 'Bundle ID / application ID',
          hint: 'This build is $buildBundleIdentifier. Change it only to try a key issued for another ID',
          initial: settings.bundleIdentifier,
          onChanged: (v) => setState(() => settings = settings.copyWith(bundleIdentifier: v.trim())),
        ),
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
        FilledButton(onPressed: sending ? null : verify, child: Text(sending ? 'Verifying…' : 'Verify connection')),
        const Hint("No service account yet? Ask Unico's onboarding team.", align: TextAlign.center),
      ],
    );
  }
}
