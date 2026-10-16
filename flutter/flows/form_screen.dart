// The create-process form. Same fields as web/views/form.ejs; buildProcessBody turns them into the request body.
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart' hide Flow;

import 'flows.dart';

// https://developer.unico.io/developers/api-reference/post-processes (duiType values)
const _duiTypes = [
  'DUI_TYPE_BR_CPF', 'DUI_TYPE_MX_CURP', 'DUI_TYPE_AR_DNI', 'DUI_TYPE_AR_LNC', 'DUI_TYPE_AR_PASSPORT', //
  'DUI_TYPE_AT_STNR', 'DUI_TYPE_BE_NN', 'DUI_TYPE_BR_CNPJ', 'DUI_TYPE_BR_PASSPORT', 'DUI_TYPE_CA_SIN',
  'DUI_TYPE_CH_AHV', 'DUI_TYPE_CL_LICENCIA_CONDUCIR', 'DUI_TYPE_CL_PASSPORT', 'DUI_TYPE_CL_RUN', 'DUI_TYPE_CO_CC',
  'DUI_TYPE_CO_LICENCIA_CONDUCCION', 'DUI_TYPE_CO_NIT', 'DUI_TYPE_CO_PASSPORT', 'DUI_TYPE_DE_IDNR', 'DUI_TYPE_DK_CPR',
  'DUI_TYPE_EC_NI', 'DUI_TYPE_ES_DNI', 'DUI_TYPE_ES_NIE', 'DUI_TYPE_FI_HETU', 'DUI_TYPE_FR_SPI', 'DUI_TYPE_GB_NINO',
  'DUI_TYPE_GT_CUI', 'DUI_TYPE_ID_NIK', 'DUI_TYPE_IE_PPSN', 'DUI_TYPE_IT_CF', 'DUI_TYPE_LK_NIC',
  'DUI_TYPE_LU_MATRICULE', 'DUI_TYPE_MX_LICENCIA_CONDUCIR', 'DUI_TYPE_MX_RFC_PERSONA_FISICA', 'DUI_TYPE_NG_BVN',
  'DUI_TYPE_NG_BVN_TOKEN', 'DUI_TYPE_NG_NIN', 'DUI_TYPE_NG_NIN_TOKEN', 'DUI_TYPE_NL_BSN', 'DUI_TYPE_NO_FNR',
  'DUI_TYPE_PE_DNI', 'DUI_TYPE_PE_PASSPORT', 'DUI_TYPE_PE_RUC', 'DUI_TYPE_PL_PESEL', 'DUI_TYPE_PT_NIF',
  'DUI_TYPE_SE_PNR', 'DUI_TYPE_SE_SAMORDNINGSNUMMER', 'DUI_TYPE_TR_TCKN', 'DUI_TYPE_US_DRIVER_LICENSE',
  'DUI_TYPE_US_ID_CARD', 'DUI_TYPE_US_PASSPORT', 'DUI_TYPE_US_PASSPORT_CARD', 'DUI_TYPE_US_POLYCARBONATE_PASSPORT',
  'DUI_TYPE_US_SSN', 'DUI_TYPE_UY_CI', 'DUI_TYPE_ZZ_EMAIL', 'DUI_TYPE_ZZ_PHONE_NUMBER',
];
const _documentPurposes = [
  'DOCUMENT_PURPOSE_ONBOARDING', 'DOCUMENT_PURPOSE_CREDIT_PROCESS', 'DOCUMENT_PURPOSE_CAR_PURCHASE', //
  'DOCUMENT_PURPOSE_PAY_BY_PAYCHECK', 'DOCUMENT_PURPOSE_FGTS',
];
const _useCases = ['USE_CASE_LOGIN', 'USE_CASE_FIN_TRANSACTIONS'];
const _purposes = ['', 'biometryonboarding', 'creditprocess', 'carpurchase', 'ageverification'];
const _currencies = ['', 'BRL', 'MXN', 'USD'];
const _locales = ['ptBr', 'enUs', 'esMx'];

// The native SDK handles the return in-app, so the docs ask for "/" as the callbackUri.
const _callbackUri = '/';

// `onSubmit` creates the process and opens the journey. It returns an error to show, or null when it went on.
class FormScreen extends StatefulWidget {
  const FormScreen({super.key, required this.flow, required this.onSubmit});

  final Flow flow;
  final Future<String?> Function(Map<String, dynamic> body) onSubmit;

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final fields = <String, String>{
    'duiType': _duiTypes.first,
    'documentPurpose': _documentPurposes.first,
    'useCase': _useCases.first,
    'locale': _locales.first,
  };
  List<XFile> documents = [];
  String? error;
  bool sending = false;

  Future<void> pickDocuments() async {
    const types = XTypeGroup(
      label: 'Documents',
      mimeTypes: ['image/*', 'application/pdf'],
      uniformTypeIdentifiers: ['public.image', 'com.adobe.pdf'],
    );
    final picked = await openFiles(acceptedTypeGroups: [types]);
    setState(() => documents = picked);
  }

  Future<void> submit() async {
    setState(() => sending = true);
    String? result;
    try {
      final files = [for (final doc in documents) base64Encode(await doc.readAsBytes())];
      result = await widget.onSubmit(buildProcessBody(widget.flow, fields, files, _callbackUri));
    } on FileSystemException catch (e) {
      result = 'Could not read a document file: $e';
    }
    if (mounted) {
      setState(() {
        error = result;
        sending = false;
      });
    }
  }

  Widget input(String name, String label, {String? hint, TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      onChanged: (v) => setState(() => fields[name] = v),
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, hintText: hint, border: const OutlineInputBorder()),
    ),
  );

  Widget picker(String name, String label, List<String> options) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: DropdownButtonFormField<String>(
      initialValue: fields[name] ?? '',
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      items: [for (final o in options) DropdownMenuItem(value: o, child: Text(o.isEmpty ? 'Not set' : o))],
      onChanged: (v) => setState(() => fields[name] = v ?? ''),
    ),
  );

  Widget section(String title) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  @override
  Widget build(BuildContext context) {
    final flow = widget.flow;
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(flow.id, style: text.headlineSmall?.copyWith(fontFamily: 'monospace')),
        Text(flow.capabilities.join(' · '), style: text.bodySmall),
        const SizedBox(height: 8),
        const Text('Use your own document. There are no test documents: the journey checks a real face against it.'),
        if (error != null)
          SelectableText(
            error!,
            style: TextStyle(fontFamily: 'monospace', color: Theme.of(context).colorScheme.error),
          ),
        section('Person'),
        picker('duiType', 'Document type', _duiTypes),
        input('duiValue', 'Your document', hint: 'Numbers only, no formatting'),
        input('friendlyName', 'Name', hint: 'Optional'),
        input('email', 'Email', hint: 'Optional', keyboard: TextInputType.emailAddress),
        input('phone', 'Phone', hint: 'Optional, e.g. 5511999999999', keyboard: TextInputType.phone),
        if (flow.extraFields.contains('document')) ...[
          section('Document for Face Document Match'),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: pickDocuments,
              child: Text(documents.isEmpty ? 'Pick document images (optional)' : '${documents.length} file(s) picked'),
            ),
          ),
          const SizedBox(height: 8),
          picker('documentPurpose', 'Document purpose', _documentPurposes),
        ],
        if (flow.extraFields.contains('useCase')) ...[
          section('Smart Revalidation'),
          picker('useCase', 'useCase', _useCases),
          input('referenceProcessId', 'Onboarding process ID', hint: 'Process to revalidate against'),
        ],
        section('Advanced'),
        input('expiresIn', 'expiresIn', hint: '3600s (default: 7 days)'),
        picker('purpose', 'purpose', _purposes),
        input('companyName', 'contextualization.company_name'),
        picker('currency', 'contextualization.currency', _currencies),
        input('price', 'contextualization.price', keyboard: const TextInputType.numberWithOptions(decimal: true)),
        picker('locale', 'reason locale', _locales),
        input('reason', 'contextualization reason'),
        Text('Create process and open with', style: text.bodySmall),
        const SizedBox(height: 4),
        FilledButton(
          onPressed: sending || (fields['duiValue'] ?? '').trim().isEmpty ? null : submit,
          child: const Text('Native SDK'),
        ),
      ],
    );
  }
}
