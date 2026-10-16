import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../flows/flows.dart';

void main() {
  final flows = parseFlows(File('flows/flows.json').readAsStringSync());
  Flow flow(String id) => flows.firstWhere((f) => f.id == id);

  test('filters by group and region', () {
    expect(filterFlows(flows, 'step-up', 'all').map((f) => f.id), ['idsmart_r2', 'idsmart_tp1']);
    expect(filterFlows(flows, 'sign-up', 'mexico').map((f) => f.id), ['idtrust_r2-idgov', 'idtrustdocs_r2-idgov']);
  });

  test('sends only the fields the user filled in', () {
    final body = buildProcessBody(
      flow('idlive_r2'),
      {'duiType': 'DUI_TYPE_BR_CPF', 'duiValue': '12345678909', 'email': '', 'purpose': ''},
      [],
      '/',
    );

    expect(
      jsonEncode(body),
      '{"flow":"idlive_r2","callbackUri":"/","person":{"duiType":"DUI_TYPE_BR_CPF","duiValue":"12345678909"}}',
    );
  });

  test('adds useCase and references for Smart Revalidation', () {
    final body = buildProcessBody(
      flow('idsmart_r2'),
      {'useCase': 'USE_CASE_LOGIN', 'referenceProcessId': 'abc-123'},
      [],
      '/',
    );

    expect(body['useCase'], 'USE_CASE_LOGIN');
    expect(
      jsonEncode(body['references']),
      '[{"referenceType":"REFERENCE_TYPE_PROCESS_ID","referenceContent":"abc-123"}]',
    );
  });

  test('adds document files only for flows with Face Document Match', () {
    final fields = {'documentPurpose': 'DOCUMENT_PURPOSE_ONBOARDING'};

    final withDocs = buildProcessBody(flow('idunicodocs_r2'), fields, ['aGVsbG8='], '/');
    final withoutDocs = buildProcessBody(flow('idlive_r2'), fields, ['aGVsbG8='], '/');

    expect(jsonEncode(withDocs['document']), '{"purpose":"DOCUMENT_PURPOSE_ONBOARDING","files":[{"data":"aGVsbG8="}]}');
    expect(withoutDocs.containsKey('document'), isFalse);
  });

  test('builds contextualization with the reason under its locale', () {
    final body = buildProcessBody(
      flow('idlive_r2'),
      {'companyName': 'Acme', 'currency': 'BRL', 'price': '10.5', 'locale': 'enUs', 'reason': 'Purchase'},
      [],
      '/',
    );

    expect(
      jsonEncode(body['contextualization']),
      '{"company_name":"Acme","currency":"BRL","price":10.5,"locale":{"enUs":{"reason":"Purchase"}}}',
    );
  });
}
