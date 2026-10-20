// The result after onSuccess(processId): a heading that names the result in words, the process as the API returns
// it, the selfie and the evidence set. One GET each, once: they start in initState, so a rebuild or a rotation
// doesn't repeat them. This repo's rule: no polling and no webhook.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/unico.dart';
import '../app/ui.dart';
import 'verdict.dart';

const _pretty = JsonEncoder.withIndent('  ');

// Errors are shown raw too: status and body exactly as Unico returned them, only indented when the body is JSON.
String describe(Object error) {
  if (error is! UnicoError) return error.toString();
  String body;
  try {
    body = _pretty.convert(jsonDecode(error.body));
  } on FormatException {
    body = error.body;
  }
  return 'HTTP ${error.status}\n$body';
}

class ResultScreen extends StatefulWidget {
  const ResultScreen({
    super.key,
    required this.unico,
    required this.processId,
    required this.onEvidenceSet,
    required this.onStepUp,
    required this.onDone,
  });

  final Unico unico;
  final String processId;
  final VoidCallback onEvidenceSet;
  final VoidCallback onStepUp;
  final VoidCallback onDone;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final Future<Map<String, dynamic>> process = widget.unico.getProcess(widget.processId);
  late final Future<Uint8List> selfie = widget.unico
      .getSelfie(widget.processId)
      .then((s) => base64Decode(s['fileContents'] as String));

  void viewSelfie(Uint8List data) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(16),
      child: Image.memory(data, semanticLabel: 'Selfie captured in the journey'),
    ),
  );

  Widget attachment(String name, Widget thumb, String? action, VoidCallback? onTap) => SizedBox(
    height: 56,
    child: Row(
      spacing: 12,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 40,
            height: 48,
            child: ColoredBox(color: ground, child: thumb),
          ),
        ),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(color: ink, fontWeight: FontWeight.bold),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onTap,
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: process,
    builder: (_, snap) {
      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
      final response = snap.data;
      final summary = response?['process'] as Map<String, dynamic>?;
      final raw = response != null ? _pretty.convert(response) : describe(snap.error!);
      return Screen(
        content: [
          if (summary != null) ...[
            () {
              final v = verdict(summary);
              final (icon, mark, back) = switch (v.tone) {
                Tone.ok => (Icons.check, okInk, okGround),
                Tone.bad => (Icons.close, badInk, badGround),
                Tone.neutral => (Icons.remove, muted, line),
              };
              final seconds = durationSeconds(summary);
              final subtitle = [?summary['flow'] as String?, if (seconds != null) '$seconds s'].join(' · ');
              return Heading(
                icon: icon,
                ink: mark,
                ground: back,
                title: v.title,
                subtitle: subtitle.isEmpty ? null : subtitle,
              );
            }(),
            Panel(
              children: [
                KeyValue('Process ID', widget.processId),
                KeyValue('State', short(summary['state']) ?? ''),
                KeyValue('Result', short(summary['result']) ?? ''),
              ],
            ),
          ] else
            const Heading(icon: Icons.remove, ink: muted, ground: line, title: 'Result'),
          Panel(children: [const Lab('Response'), CodeBlock(raw)]),
          Panel(
            children: [
              FutureBuilder(
                future: selfie,
                builder: (_, img) => Column(
                  children: [
                    attachment(
                      'Selfie',
                      img.hasData
                          ? Image.memory(img.data!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())
                          : const SizedBox(),
                      img.hasData ? 'View' : null,
                      img.hasData ? () => viewSelfie(img.data!) : null,
                    ),
                    if (img.hasError) CodeBlock(describe(img.error!)),
                  ],
                ),
              ),
              const Divider(height: 1, color: line),
              attachment('Evidence set (PDF)', const SizedBox(), 'Open', widget.onEvidenceSet),
            ],
          ),
        ],
        dock: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: widget.onStepUp, child: const Text('Try step-up on this process')),
          ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(onPressed: widget.onDone, child: const Text('Run another flow')),
          ),
        ],
      );
    },
  );
}
