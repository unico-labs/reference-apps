// Pure logic behind the flows menu and the create-process form. No Flutter here, so it reads the same anywhere.
// Field names follow https://developer.unico.io/developers/api-reference/post-processes
import 'dart:convert';

// One row of flows.json, a copy of the root flows.json (CI fails if it drifts).
class Flow {
  Flow.fromJson(Map<String, dynamic> json)
    : id = json['id'] as String,
      group = json['group'] as String,
      region = json['region'] as String,
      capabilities = List<String>.from(json['capabilities'] as List),
      extraFields = List<String>.from(json['extraFields'] as List);

  final String id;
  final String group;
  final String region;
  final List<String> capabilities;
  final List<String> extraFields;
}

List<Flow> parseFlows(String json) =>
    (jsonDecode(json) as List).map((row) => Flow.fromJson(row as Map<String, dynamic>)).toList();

List<Flow> filterFlows(List<Flow> flows, String group, String region) =>
    flows.where((f) => f.group == group && (region == 'all' || f.region == region)).toList();

// Drops empty values, so the API only receives what the user filled in.
void _putIfSet(Map<String, dynamic> map, String key, String? value) {
  if (value != null && value.isNotEmpty) map[key] = value;
}

// `fields` holds the form values as strings; `documentFiles` holds the document files as base64 strings.
Map<String, dynamic> buildProcessBody(
  Flow flow,
  Map<String, String> fields,
  List<String> documentFiles,
  String callbackUri,
) {
  final person = <String, dynamic>{};
  for (final key in ['duiType', 'duiValue', 'friendlyName', 'email', 'phone']) {
    _putIfSet(person, key, fields[key]);
  }
  final body = <String, dynamic>{'flow': flow.id, 'callbackUri': callbackUri, 'person': person};

  if (flow.extraFields.contains('document') && documentFiles.isNotEmpty) {
    final document = <String, dynamic>{};
    _putIfSet(document, 'purpose', fields['documentPurpose']);
    document['files'] = [
      for (final data in documentFiles) {'data': data},
    ];
    body['document'] = document;
  }
  if (flow.extraFields.contains('useCase')) _putIfSet(body, 'useCase', fields['useCase']);
  final referenceProcessId = fields['referenceProcessId'];
  if (flow.extraFields.contains('references') && referenceProcessId != null && referenceProcessId.isNotEmpty) {
    body['references'] = [
      {'referenceType': 'REFERENCE_TYPE_PROCESS_ID', 'referenceContent': referenceProcessId},
    ];
  }

  _putIfSet(body, 'expiresIn', fields['expiresIn']);
  _putIfSet(body, 'purpose', fields['purpose']);

  final contextualization = <String, dynamic>{};
  _putIfSet(contextualization, 'company_name', fields['companyName']);
  _putIfSet(contextualization, 'currency', fields['currency']);
  final price = double.tryParse(fields['price'] ?? '');
  if (price != null) contextualization['price'] = price;
  final reason = fields['reason'];
  if (reason != null && reason.isNotEmpty) {
    contextualization['locale'] = {
      fields['locale'] ?? 'ptBr': {'reason': reason},
    };
  }
  if (contextualization.isNotEmpty) body['contextualization'] = contextualization;
  return body;
}
