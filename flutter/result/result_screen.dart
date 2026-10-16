// The result after onSuccess(processId): the process as the API returns it, without interpreting it, plus the selfie
// and a button for the evidence set. One GET each, once: they start in initState, so a rebuild or a rotation
// doesn't repeat them. This repo's rule: no polling and no webhook.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../api/unico.dart';

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
    required this.onDone,
  });

  final Unico unico;
  final String processId;
  final VoidCallback onEvidenceSet;
  final VoidCallback onDone;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late final Future<String> process = widget.unico
      .getProcess(widget.processId)
      .then(_pretty.convert, onError: (Object e) => describe(e));
  late final Future<Uint8List> selfie = widget.unico
      .getSelfie(widget.processId)
      .then((s) => base64Decode(s['fileContents'] as String));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 12);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('GET /client/v1/process/{id}', style: text.titleMedium),
        FutureBuilder(
          future: process,
          builder: (_, snap) =>
              snap.hasData ? SelectableText(snap.data!, style: mono) : const LinearProgressIndicator(),
        ),
        const SizedBox(height: 16),
        Text('GET /client/v1/process/{id}/selfie', style: text.titleMedium),
        FutureBuilder(
          future: selfie,
          builder: (_, snap) => switch (snap) {
            AsyncSnapshot(:final data?) => Image.memory(
              data,
              semanticLabel: 'Selfie captured in the journey',
              errorBuilder: (_, e, _) => SelectableText(e.toString(), style: mono),
            ),
            AsyncSnapshot(:final error?) => SelectableText(describe(error), style: mono),
            _ => const LinearProgressIndicator(),
          },
        ),
        const SizedBox(height: 16),
        Text('GET /client/v1/process/{id}/evidenceset', style: text.titleMedium),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(onPressed: widget.onEvidenceSet, child: const Text('Open evidence set (PDF)')),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(onPressed: widget.onDone, child: const Text('Run another flow')),
        ),
      ],
    );
  }
}
