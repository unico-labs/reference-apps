// Run a flow: the create-process form, the Customize sheet and the error screen. Same fields as web/views/form.ejs;
// buildProcessBody turns them into the request body.
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../app/ui.dart';
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
  '', 'DOCUMENT_PURPOSE_ONBOARDING', 'DOCUMENT_PURPOSE_CREDIT_PROCESS', 'DOCUMENT_PURPOSE_CAR_PURCHASE', //
  'DOCUMENT_PURPOSE_PAY_BY_PAYCHECK', 'DOCUMENT_PURPOSE_FGTS',
];
// The examples in the Create Process docs.
const _useCases = ['USE_CASE_LOGIN', 'USE_CASE_FIN_TRANSACTIONS'];
const _purposes = ['', 'biometryonboarding', 'creditprocess', 'carpurchase', 'ageverification'];
const _currencies = ['', 'BRL', 'MXN', 'USD'];
const _locales = ['ptBr', 'enUs', 'esMx'];

// The native SDK handles the return in-app, so the docs ask for "/" as the callbackUri.
const _callbackUri = '/';
const _pretty = JsonEncoder.withIndent('  ');

// `onSubmit` creates the process and opens the journey. It returns an error to show, or null when it went on.
// `reference` is the last finished journey: it fills the reference field, turned on when `stepUp` asks for it.
class FormScreen extends StatefulWidget {
  const FormScreen({super.key, required this.reference, required this.stepUp, required this.onSubmit});

  final String? reference;
  final bool stepUp;
  final Future<String?> Function(Map<String, dynamic> body) onSubmit;

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  late final fields = <String, String>{
    'duiType': _duiTypes.first,
    'useCase': _useCases.first,
    'locale': _locales.first,
    'referenceProcessId': widget.reference ?? '',
    'withReferences': '${widget.stepUp}',
  };
  List<XFile> documents = [];
  String? error;
  bool sending = false;

  void set(String name, String value) => setState(() => fields[name] = value);

  Future<void> pickDocuments(StateSetter refresh) async {
    const types = XTypeGroup(
      label: 'Documents',
      mimeTypes: ['image/*', 'application/pdf'],
      uniformTypeIdentifiers: ['public.image', 'com.adobe.pdf'],
    );
    final picked = await openFiles(acceptedTypeGroups: [types]);
    setState(() => documents = picked);
    refresh(() {});
  }

  Future<void> submit() async {
    setState(() => sending = true);
    String? result;
    try {
      final files = [for (final doc in documents) base64Encode(await doc.readAsBytes())];
      result = await widget.onSubmit(buildProcessBody(fields, files, _callbackUri));
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

  // The Customize sheet keeps its own setState, so a switch redraws the sheet as well as the preview behind it.
  void customize() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (context) => StatefulBuilder(
      builder: (context, refresh) {
        void change(String name, String value) {
          set(name, value);
          refresh(() {});
        }

        Widget field(
          String name,
          String label,
          String api, {
          String? placeholder,
          String? hint,
          TextInputType? keyboard,
        }) => Field(
          label: label,
          api: api,
          placeholder: placeholder,
          hint: hint,
          keyboard: keyboard,
          initial: fields[name],
          onChanged: (v) => change(name, v),
        );
        Widget select(String name, String label, String api, List<String> options) => Select(
          label: label,
          api: api,
          options: options,
          value: fields[name] ?? '',
          onChanged: (v) => change(name, v),
        );
        Widget extra(String name, String label, String api, String hint, List<Widget> children) {
          final on = fields[name] == 'true';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              InkWell(
                onTap: () => change(name, '${!on}'),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(value: on, onChanged: (v) => change(name, '${v ?? false}')),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FieldLabel(label, api: api),
                            Hint(hint),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (on) ExtraBox(children: children),
            ],
          );
        }

        Widget pair(Widget a, Widget b) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Expanded(child: a),
            Expanded(child: b),
          ],
        );

        return FractionallySizedBox(
          heightFactor: 0.9,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 4),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Customize request',
                        style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: muted),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (final w in <Widget>[
                      field('friendlyName', 'Name', 'person.friendlyName', placeholder: 'Full name (optional)'),
                      pair(
                        field('email', 'Email', 'person.email', keyboard: TextInputType.emailAddress),
                        field(
                          'phone',
                          'Phone',
                          'person.phone',
                          placeholder: '5511999999999',
                          keyboard: TextInputType.phone,
                        ),
                      ),
                      pair(
                        field('expiresIn', 'Expires in', 'expiresIn', placeholder: '3600s'),
                        select('purpose', 'Purpose', 'purpose', _purposes),
                      ),
                      const Lab('Extra fields this flow needs'),
                      extra('withDocument', 'Document image', 'document', 'Flows with Face Document Match.', [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          spacing: 6,
                          children: [
                            const FieldLabel('Document files', api: 'document.files'),
                            OutlinedButton(
                              onPressed: () => pickDocuments(refresh),
                              child: Text(
                                documents.isEmpty ? 'Pick document images' : '${documents.length} file(s) picked',
                              ),
                            ),
                            const Hint("Image of the person's document, used by Face Document Match."),
                          ],
                        ),
                        select('documentPurpose', 'Document purpose', 'document.purpose', _documentPurposes),
                      ]),
                      extra(
                        'withReferences',
                        'Use case and reference',
                        'useCase, references',
                        'Step-up flows that revalidate an earlier process.',
                        [
                          select('useCase', 'Use case', 'useCase', _useCases),
                          field(
                            'referenceProcessId',
                            'Reference process ID',
                            'references',
                            hint: widget.reference == null
                                ? null
                                : 'Filled from your last test. Change it if you want another process.',
                          ),
                        ],
                      ),
                      extra(
                        'withContextualization',
                        'Contextualization',
                        'contextualization',
                        'Company, price and reason shown to the person in the journey.',
                        [
                          field('companyName', 'Company name', 'company_name'),
                          pair(
                            select('currency', 'Currency', 'currency', _currencies),
                            field(
                              'price',
                              'Price',
                              'price',
                              keyboard: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                          pair(
                            select('locale', 'Reason language', 'locale', _locales),
                            field('reason', 'Reason', 'locale.{language}.reason'),
                          ),
                        ],
                      ),
                      const Hint(
                        'Not sure? Leave them off. If the API asks for more, the error names the missing field.',
                      ),
                    ]) ...[w, const SizedBox(height: 12)],
                  ],
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: line)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: SafeArea(
                  top: false,
                  child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    // On the error screen the form waits behind, still filled in. Try again brings it back.
    final failed = error;
    if (failed != null) {
      return Screen(
        content: [
          Heading(
            icon: Icons.close,
            ink: badInk,
            ground: badGround,
            title: "Couldn't start the test",
            subtitle: '${fields['flow'] ?? ''} · process was not created',
          ),
          Panel(children: [const Lab('Response'), CodeBlock(failed)]),
          const Panel(
            center: true,
            children: [
              Lab('What you can do'),
              Text(
                'Check the information you entered and confirm the flow is active on your account.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ink, fontSize: 14),
              ),
            ],
          ),
        ],
        dock: [FilledButton(onPressed: () => setState(() => error = null), child: const Text('Try again'))],
      );
    }
    // The preview shows the body the app will send; files stand in as placeholders.
    final preview = buildProcessBody(fields, [for (final _ in documents) '<file as base64>'], _callbackUri);
    return Screen(
      content: [
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Which flow do you want to test?',
              style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            Hint(
              "Type the flow name Unico gave you. If your account doesn't have it, the test fails and we show the API error.",
            ),
          ],
        ),
        Field(
          label: 'Flow',
          api: 'flow',
          required: true,
          placeholder: 'e.g. id',
          hint: 'Flow names are listed on the Flows page of the Unico docs.',
          mono: true,
          initial: fields['flow'],
          onChanged: (v) => set('flow', v),
        ),
        Select(
          label: 'Document type',
          api: 'person.duiType',
          options: _duiTypes,
          value: fields['duiType']!,
          onChanged: (v) => set('duiType', v),
        ),
        Field(
          label: 'Document number',
          api: 'person.duiValue',
          placeholder: 'Numbers only, no formatting',
          hint: "The person's own document. Leave it empty if the flow doesn't ask for one.",
          initial: fields['duiValue'],
          onChanged: (v) => set('duiValue', v),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            const Lab('Request your backend sends'),
            CodeBlock('POST /client/v1/process\n${_pretty.convert(preview)}'),
          ],
        ),
      ],
      dock: [
        Row(
          spacing: 10,
          children: [
            OutlinedButton(onPressed: customize, child: const Text('Customize')),
            Expanded(
              child: FilledButton(
                onPressed: sending || (fields['flow'] ?? '').trim().isEmpty ? null : submit,
                child: Text(sending ? 'Starting…' : 'Start test'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
