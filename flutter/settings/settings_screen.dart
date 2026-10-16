// DEMO ONLY: the settings screen. In production none of this is on the device; your server holds the credentials.
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import 'settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.initial, required this.onSave});

  final Settings initial;
  final ValueChanged<Settings> onSave;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Settings settings = widget.initial;
  // The stored key is never shown again. Leave the field empty to keep it.
  final pem = TextEditingController();
  String? error;

  // A .pem has no registered type on either platform, so the picker accepts any file and the key check decides.
  Future<void> importPem() async {
    final file = await openFile();
    if (file != null) pem.text = await file.readAsString();
  }

  void save() {
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
    setState(() => error = problem);
    if (problem == null) widget.onSave(next);
  }

  Widget field(String label, String value, ValueChanged<String> onChanged, {String? helper}) => TextFormField(
    initialValue: value,
    onChanged: (v) => setState(() => onChanged(v.trim())),
    decoration: InputDecoration(labelText: label, helperText: helper, border: const OutlineInputBorder()),
  );

  @override
  void dispose() {
    pem.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Hosts come filled in with UAT. See developer.unico.io/developers/start/environments.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 12),
        field('Identity host', settings.identityHost, (v) => settings = settings.copyWith(identityHost: v)),
        const SizedBox(height: 12),
        field('API host', settings.apiHost, (v) => settings = settings.copyWith(apiHost: v)),
        const SizedBox(height: 12),
        field('Service account', settings.account, (v) => settings = settings.copyWith(account: v)),
        const SizedBox(height: 12),
        field(
          'Tenant',
          settings.tenant,
          (v) => settings = settings.copyWith(tenant: v),
          helper: 'Signs as ${settings.serviceAccount}',
        ),
        const SizedBox(height: 12),
        field(
          'SDK key',
          settings.sdkKey,
          (v) => settings = settings.copyWith(sdkKey: v),
          helper: "Linked by Unico to this app's bundle ID / application ID",
        ),
        const SizedBox(height: 16),
        Text('Private key (.pem)', style: text.titleMedium),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: importPem, child: const Text('Import file')),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: pem,
          minLines: 4,
          maxLines: 8,
          style: text.bodySmall?.copyWith(fontFamily: 'monospace'),
          decoration: InputDecoration(
            labelText: widget.initial.privateKeyPem.isEmpty
                ? 'Or paste it here'
                : 'Saved. Paste or import to replace it',
            border: const OutlineInputBorder(),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(onPressed: save, child: const Text('Save')),
      ],
    );
  }
}
