import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../flows/flows.dart';

void main() {
  const person = {'flow': 'idlive_r2', 'duiType': 'DUI_TYPE_BR_CPF', 'duiValue': '12345678909'};
  Map<String, dynamic> body([Map<String, String> extra = const {}, List<String> files = const []]) =>
      buildProcessBody({...person, ...extra}, files, '/');

  test('sends the typed flow and only the fields the user filled in', () {
    expect(
      jsonEncode(body({'flow': ' idlive_r2 ', 'email': '', 'purpose': ''})),
      jsonEncode({
        'flow': 'idlive_r2',
        'callbackUri': '/',
        'person': {'duiType': 'DUI_TYPE_BR_CPF', 'duiValue': '12345678909'},
      }),
    );
  });

  test('leaves the person out when no document number was typed', () {
    expect(buildProcessBody({'flow': 'idlive_r2', 'duiType': 'DUI_TYPE_BR_CPF'}, [], '/'), {
      'flow': 'idlive_r2',
      'callbackUri': '/',
    });
  });

  test('maps the name, email and phone to the person', () {
    expect(body({'friendlyName': 'Ana', 'email': 'ana@example.com', 'phone': '5511999999999'})['person'], {
      'duiType': 'DUI_TYPE_BR_CPF',
      'duiValue': '12345678909',
      'friendlyName': 'Ana',
      'email': 'ana@example.com',
      'phone': '5511999999999',
    });
  });

  test('adds the document files and purpose when the document is turned on', () {
    expect(body({'withDocument': 'true', 'documentPurpose': 'DOCUMENT_PURPOSE_ONBOARDING'}, ['aGVsbG8='])['document'], {
      'purpose': 'DOCUMENT_PURPOSE_ONBOARDING',
      'files': [
        {'data': 'aGVsbG8='},
      ],
    });
  });

  test('leaves the document out when it is turned off or has no file', () {
    expect(body({}, ['aGVsbG8=']).containsKey('document'), isFalse);
    expect(body({'withDocument': 'true'}).containsKey('document'), isFalse);
  });

  test('adds useCase and a process reference when they are turned on', () {
    final b = body({'withReferences': 'true', 'useCase': 'USE_CASE_LOGIN', 'referenceProcessId': 'abc-123'});

    expect(b['useCase'], 'USE_CASE_LOGIN');
    expect(b['references'], [
      {'referenceType': 'REFERENCE_TYPE_PROCESS_ID', 'referenceContent': 'abc-123'},
    ]);
  });

  test('leaves useCase and references out when they are turned off', () {
    expect(body({'useCase': 'USE_CASE_LOGIN', 'referenceProcessId': 'abc-123'}).keys, [
      'flow',
      'callbackUri',
      'person',
    ]);
  });

  test('maps expiresIn and purpose', () {
    final b = body({'expiresIn': '3600s', 'purpose': 'creditprocess'});

    expect(b['expiresIn'], '3600s');
    expect(b['purpose'], 'creditprocess');
  });

  test('builds contextualization with the reason under its locale when it is turned on', () {
    final b = body({
      'withContextualization': 'true',
      'companyName': 'Acme',
      'currency': 'BRL',
      'price': '10.5',
      'locale': 'enUs',
      'reason': 'Purchase',
    });

    expect(b['contextualization'], {
      'company_name': 'Acme',
      'currency': 'BRL',
      'price': 10.5,
      'locale': {
        'enUs': {'reason': 'Purchase'},
      },
    });
  });

  test('leaves contextualization out when it is turned off', () {
    expect(body({'companyName': 'Acme'}).containsKey('contextualization'), isFalse);
  });
}
