import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

import 'package:unico_reference/main.dart';
import 'package:unico_reference/settings/settings.dart';
import 'package:unico_reference/settings/settings_screen.dart';
import 'package:unico_reference/ui.dart';

import 'unico_test.dart' show generateKeys;

String pkcs8Pem(RSAPrivateKey k) {
  final rsa = ASN1Sequence(
    elements: [
      ASN1Integer(BigInt.zero),
      ASN1Integer(k.modulus),
      ASN1Integer(k.publicExponent),
      ASN1Integer(k.privateExponent),
      ASN1Integer(k.p),
      ASN1Integer(k.q),
      ASN1Integer(k.privateExponent! % (k.p! - BigInt.one)),
      ASN1Integer(k.privateExponent! % (k.q! - BigInt.one)),
      ASN1Integer(k.q!.modInverse(k.p!)),
    ],
  );
  final der = ASN1Sequence(
    elements: [
      ASN1Integer(BigInt.zero),
      ASN1Sequence(elements: [ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'), ASN1Null()]),
      ASN1OctetString(octets: rsa.encode()),
    ],
  ).encode();
  return '-----BEGIN PRIVATE KEY-----\n${base64.encode(der)}\n-----END PRIVATE KEY-----';
}

Finder field(String label) =>
    find.descendant(of: find.widgetWithText(Field, label), matching: find.byType(TextFormField));

void main() {
  testWidgets('opens Welcome when the device has no credentials', (tester) async {
    await tester.pumpWidget(const ReferenceApp(settings: Settings()));

    expect(find.text('See how a Unico integration works'), findsOneWidget);
    expect(find.text('Set up this app'), findsOneWidget);
  });

  testWidgets('Get started opens the API credentials step', (tester) async {
    await tester.pumpWidget(const ReferenceApp(settings: Settings()));
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 2'), findsOneWidget);
    expect(find.text('API credentials'), findsOneWidget);
    expect(find.text('Verify credentials'), findsOneWidget);
  });

  testWidgets('verifies the credentials, then saves the SDK settings and opens Run a flow', (tester) async {
    HttpOverrides.global = null;
    FlutterSecureStorage.setMockInitialValues({});
    final pem = pkcs8Pem(generateKeys().privateKey);
    final fake = (await tester.runAsync(() => HttpServer.bind(InternetAddress.loopbackIPv4, 0)))!;
    addTearDown(() => fake.close(force: true));
    fake.listen((request) async {
      await utf8.decodeStream(request);
      request.response
        ..headers.contentType = ContentType.json
        ..write('{"access_token":"token","token_type":"Bearer","expires_in":3600}');
      await request.response.close();
    });
    final baseUrl = 'http://127.0.0.1:${fake.port}';

    await tester.pumpWidget(
      ReferenceApp(
        settings: Settings(identityHost: baseUrl, apiHost: baseUrl),
      ),
    );
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();
    await tester.enterText(field('Service account'), 'my-account');
    await tester.enterText(field('Tenant ID'), 'abc123');
    await tester.enterText(field('Private key (.pem)'), pem);
    await tester.tap(find.text('Verify credentials'));
    for (var i = 0; i < 100 && find.text('Connected to the API').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Connected to the API'), findsOneWidget);
    expect(find.text('Unico UAT accepted your credentials.'), findsOneWidget);
    expect(find.text('Step 1 of 2 · done'), findsOneWidget);

    await tester.tap(find.text('Continue to SDK settings'));
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 2'), findsOneWidget);
    expect(find.text(buildBundleIdentifier), findsOneWidget);
    expect(
      find.text('Bundle ID (iOS) or application ID (Android) of this app. The SDK key must be issued for it.'),
      findsOneWidget,
    );

    await tester.enterText(field('SDK key'), 'sdk-key');
    await tester.tap(find.text('Save and continue'));
    for (var i = 0; i < 100 && find.text('Run a flow').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('Run a flow'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('the connected pill opens the API credentials step, and Back returns to the form', (tester) async {
    final pem = pkcs8Pem(generateKeys().privateKey);
    await tester.pumpWidget(
      ReferenceApp(
        settings: Settings(account: 'my-account', tenant: 'abc123', sdkKey: 'sdk-key', privateKeyPem: pem),
      ),
    );
    await tester.tap(find.text('✓ UAT · my-account'));
    await tester.pumpAndSettle();

    expect(find.text('API credentials'), findsOneWidget);
    expect(find.text('See how a Unico integration works'), findsNothing);
    expect(find.text('Key added. Paste or import to replace it'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Run a flow'), findsOneWidget);
  });

  testWidgets('SDK settings refuses to save settings without credentials', (tester) async {
    Settings? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SdkSettingsScreen(
            initial: const Settings(),
            onSave: (s) async {
              saved = s;
              return null;
            },
          ),
        ),
      ),
    );
    await tester.enterText(field('SDK key'), 'sdk-key');
    await tester.tap(find.text('Save and continue'));
    await tester.pumpAndSettle();

    expect(saved, isNull);
  });
}
