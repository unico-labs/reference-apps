// The evidence set: one GET when the user opens it, rendered in the app with the platform's own PDF engine
// (PdfRenderer on Android, PDFKit on iOS) through pdfx. It holds biometric data, so it isn't handed to another app
// and no copy is kept: the temporary file the renderer needs is deleted as soon as the pages are drawn.
// The file is written here rather than with pdfx's openData, which leaves its own copy in the cache on Android.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import '../api/unico.dart';
import 'result_screen.dart';

// Judgment call: 2x the PDF's point size reads well on a phone without large bitmaps.
const _scale = 2;

class EvidenceSetScreen extends StatefulWidget {
  const EvidenceSetScreen({super.key, required this.unico, required this.processId});

  final Unico unico;
  final String processId;

  @override
  State<EvidenceSetScreen> createState() => _EvidenceSetScreenState();
}

class _EvidenceSetScreenState extends State<EvidenceSetScreen> {
  // fileContents is the PDF in base64. contentType comes back as "x-pdf"; it's ignored here.
  late final Future<List<Uint8List>> pages = widget.unico
      .getEvidenceSet(widget.processId)
      .then((e) => _render(base64Decode(e['fileContents'] as String)));

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: pages,
    builder: (_, snap) => switch (snap) {
      AsyncSnapshot(:final data?) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final page in data)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Image.memory(page, semanticLabel: 'Evidence set page'),
            ),
        ],
      ),
      AsyncSnapshot(:final error?) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          describe(error),
          style: const TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Menlo'], fontSize: 12),
        ),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    },
  );
}

Future<List<Uint8List>> _render(Uint8List pdf) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/evidence-set-${DateTime.now().microsecondsSinceEpoch}.pdf');
  try {
    await file.writeAsBytes(pdf, flush: true);
    final document = await PdfDocument.openFile(file.path);
    try {
      return [for (var i = 1; i <= document.pagesCount; i++) await _renderPage(await document.getPage(i))];
    } finally {
      await document.close();
    }
  } finally {
    if (await file.exists()) await file.delete();
  }
}

Future<Uint8List> _renderPage(PdfPage page) async {
  try {
    final image = await page.render(
      width: page.width * _scale,
      height: page.height * _scale,
      format: PdfPageImageFormat.png,
      backgroundColor: '#FFFFFF',
    );
    return image!.bytes;
  } finally {
    await page.close();
  }
}
