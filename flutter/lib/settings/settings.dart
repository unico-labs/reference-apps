// DEMO ONLY: credentials typed into the device. In production the service account key lives only on your server,
// which creates the process and hands the app nothing but the webAppToken. Don't carry this file into an app.
//
// What it does, for the demo: one environment (UAT hosts prefilled, editable), the service account, the SDK key,
// and the .pem key, all in flutter_secure_storage: on Android encrypted with a key that never leaves the Android
// Keystore (the manifest sets allowBackup="false"), on iOS in the Keychain with a "this device only" accessibility,
// so the key isn't synced to iCloud or restored on another device.
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/unico.dart';

// This build's ID. Keep it equal to applicationId in android/app/build.gradle.kts and PRODUCT_BUNDLE_IDENTIFIER
// in the iOS project, and change all three to the one Unico linked to your SDK key.
// A constant keeps the build free of package_info_plus. Read it at runtime if the IDs differ per platform.
const buildBundleIdentifier = 'io.unico.reference';

class Settings {
  // Defaults are Hosts.uat, spelled out because a default value has to be a constant.
  const Settings({
    this.identityHost = 'https://identityhomolog.acesso.io',
    this.apiHost = 'https://api.idcloud.uat.unico.app',
    this.account = '',
    this.tenant = '',
    this.sdkKey = '',
    this.privateKeyPem = '',
  });

  final String identityHost;
  final String apiHost;
  final String account;
  final String tenant;
  // Issued by Unico's Onboarding team for buildBundleIdentifier:
  // https://developer.unico.io/developers/sdks-and-tools/flutter/installation/specific-setup
  final String sdkKey;
  final String privateKeyPem;

  Hosts get hosts => Hosts(identity: _trimSlash(identityHost), api: _trimSlash(apiHost));

  // The `iss` claim: https://developer.unico.io/developers/start/authentication
  String get serviceAccount => '$account@$tenant.iam.acesso.io';

  bool get hasCredentials => [identityHost, apiHost, account, tenant, privateKeyPem].every((v) => v.trim().isNotEmpty);

  bool get isComplete => hasCredentials && sdkKey.trim().isNotEmpty;

  Settings copyWith({
    String? identityHost,
    String? apiHost,
    String? account,
    String? tenant,
    String? sdkKey,
    String? privateKeyPem,
  }) => Settings(
    identityHost: identityHost ?? this.identityHost,
    apiHost: apiHost ?? this.apiHost,
    account: account ?? this.account,
    tenant: tenant ?? this.tenant,
    sdkKey: sdkKey ?? this.sdkKey,
    privateKeyPem: privateKeyPem ?? this.privateKeyPem,
  );

  // Keeps the key out of logs and crash reports.
  @override
  String toString() => 'Settings(identityHost: $identityHost, apiHost: $apiHost, account: $account, tenant: $tenant)';
}

String _trimSlash(String host) => host.trim().replaceFirst(RegExp(r'/+$'), '');

// A key copied from an email often loses its PEM header or arrives in another format. Check it when it's saved,
// so the error names what was found instead of failing on the first token request.
RSAPrivateKey parsePrivateKey(String pem) {
  final header = RegExp(r'-----BEGIN ([A-Z ]+)-----').firstMatch(pem)?.group(1);
  if (header != 'PRIVATE KEY') {
    throw FormatException(
      'Not a PEM private key (${header == null ? 'no PEM header' : 'found: $header'}). '
      'It should start with -----BEGIN PRIVATE KEY-----.',
    );
  }
  try {
    return RSAPrivateKey(pem);
  } on Object {
    throw const FormatException('Not a valid RSA private key.');
  }
}

class SettingsStore {
  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  Future<Settings> load() async {
    // If the Keystore key is gone (app data cleared, device reset), nothing reads back and Settings opens first.
    final Map<String, String> v;
    try {
      v = await _storage.readAll();
    } on Object {
      return const Settings();
    }
    const defaults = Settings();
    return Settings(
      identityHost: v['identityHost'] ?? defaults.identityHost,
      apiHost: v['apiHost'] ?? defaults.apiHost,
      account: v['account'] ?? '',
      tenant: v['tenant'] ?? '',
      sdkKey: v['sdkKey'] ?? '',
      privateKeyPem: v['privateKey'] ?? '',
    );
  }

  Future<void> save(Settings settings) async {
    await _storage.write(key: 'identityHost', value: settings.identityHost);
    await _storage.write(key: 'apiHost', value: settings.apiHost);
    await _storage.write(key: 'account', value: settings.account);
    await _storage.write(key: 'tenant', value: settings.tenant);
    await _storage.write(key: 'sdkKey', value: settings.sdkKey);
    await _storage.write(key: 'privateKey', value: settings.privateKeyPem);
  }
}
