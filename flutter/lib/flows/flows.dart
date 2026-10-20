// Pure logic behind the create-process form. No Flutter here, so it reads the same anywhere.
// Field names follow https://developer.unico.io/developers/api-reference/post-processes

// Drops empty values, so the API only receives what the user filled in.
void _putIfSet(Map<String, dynamic> map, String key, String? value) {
  if (value != null && value.isNotEmpty) map[key] = value;
}

// `fields` holds the form values as strings; `documentFiles` holds the document files as base64 strings.
// The flow is whatever the user typed: the app doesn't know which flows the account has, so a wrong or disabled
// one fails on creation. `withDocument`, `withReferences` and `withContextualization` are the switches that turn
// the extra fields on.
Map<String, dynamic> buildProcessBody(Map<String, String> fields, List<String> documentFiles, String callbackUri) {
  bool on(String name) => fields[name] == 'true';
  final body = <String, dynamic>{'flow': (fields['flow'] ?? '').trim(), 'callbackUri': callbackUri};

  // Not every flow asks for the person's document. Without its number, the type alone means nothing.
  final hasDocument = (fields['duiValue'] ?? '').isNotEmpty;
  final person = <String, dynamic>{};
  if (hasDocument) _putIfSet(person, 'duiType', fields['duiType']);
  for (final key in ['duiValue', 'friendlyName', 'email', 'phone']) {
    _putIfSet(person, key, fields[key]);
  }
  if (person.isNotEmpty) body['person'] = person;

  if (on('withDocument') && documentFiles.isNotEmpty) {
    final document = <String, dynamic>{};
    _putIfSet(document, 'purpose', fields['documentPurpose']);
    document['files'] = [
      for (final data in documentFiles) {'data': data},
    ];
    body['document'] = document;
  }
  if (on('withReferences')) _putIfSet(body, 'useCase', fields['useCase']);
  final referenceProcessId = fields['referenceProcessId'];
  if (on('withReferences') && referenceProcessId != null && referenceProcessId.isNotEmpty) {
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
  if (on('withContextualization') && contextualization.isNotEmpty) body['contextualization'] = contextualization;
  return body;
}
