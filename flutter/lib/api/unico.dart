// Unico client: JWT, access token, Create Process, Get Process, selfie, evidence set.
// Plain Dart (no Flutter imports), so it reads the same on a Dart server.
//
// DEMO ONLY: this app signs the JWT on the device because it has no server. In production this whole file
// runs on your server and the device never holds the service account key. See web/api/unico.js for the same
// client on a server, and https://developer.unico.io/developers/start/authentication ("Never do this on the client side").
import 'dart:async';
import 'dart:convert';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:http/http.dart' as http;

// https://developer.unico.io/developers/start/environments
class Hosts {
  const Hosts({required this.identity, required this.api});

  final String identity;
  final String api;

  static const uat = Hosts(identity: 'https://identityhomolog.acesso.io', api: 'https://api.idcloud.uat.unico.app');
  static const prod = Hosts(identity: 'https://identity.acesso.io', api: 'https://api.idcloud.unico.app');

  @override
  bool operator ==(Object other) => other is Hosts && other.identity == identity && other.api == api;

  @override
  int get hashCode => Object.hash(identity, api);
}

// Any non-2xx answer from Unico, with the status and body exactly as returned.
class UnicoError implements Exception {
  UnicoError(this.status, this.body);

  final int status;
  final String body;

  @override
  String toString() => 'Unico API returned $status';
}

// Bad input caught here, before anything is sent to Unico.
class InvalidInputError implements Exception {
  InvalidInputError(this.message);

  final String message;

  @override
  String toString() => message;
}

// Renewed when 10 minutes or less remain: https://developer.unico.io/developers/start/authentication
const _renewBefore = Duration(minutes: 10);

// Judgment call: long enough for a slow mobile network, short enough that a dead connection surfaces as an error.
const _timeout = Duration(seconds: 30);

// Ids are interpolated into the URL, so anything like `../` is refused before calling Unico.
String _processId(String id) {
  if (!RegExp(r'^[\w-]+$').hasMatch(id)) throw InvalidInputError('invalid process id');
  return id;
}

class Unico {
  // `privateKey` is the service account's .pem, parsed with RSAPrivateKey(pem) from dart_jsonwebtoken.
  Unico({required this.serviceAccount, required this.privateKey, required this.hosts});

  final String serviceAccount;
  final RSAPrivateKey privateKey;
  final Hosts hosts;

  String? _accessToken;
  DateTime _renewAt = DateTime.fromMillisecondsSinceEpoch(0);
  Future<String>? _pending;

  // https://developer.unico.io/developers/start/authentication
  // DEMO ONLY: signs with the service account key held on the device. Don't carry this into an app.
  String _signAssertion() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    // Only these claims: any other (sub, jti, nbf) is refused with error 1.2.22.
    final payload = {'iss': serviceAccount, 'aud': hosts.identity, 'scope': '*', 'iat': now, 'exp': now + 3600};
    return JWT(payload).sign(privateKey, algorithm: JWTAlgorithm.RS256, noIssueAt: true);
  }

  Future<String> _requestToken() async {
    final res = await http
        .post(
          Uri.parse('${hosts.identity}/oauth2/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer', 'assertion': _signAssertion()},
        )
        .timeout(_timeout);
    final data = _parse(res);
    final token = data['access_token'];
    final expiresIn = data['expires_in'];
    // A 2xx answer without a token is still Unico's answer, so it reaches the caller like any other.
    if (token is! String || expiresIn is! int) {
      throw UnicoError(res.statusCode, utf8.decode(res.bodyBytes, allowMalformed: true));
    }

    _accessToken = token;
    _renewAt = DateTime.now().add(Duration(seconds: expiresIn) - _renewBefore);
    return token;
  }

  // Public so an app can check its credentials on their own: a token proves the account, tenant and key are right,
  // but says nothing about which flows the account has.
  Future<String> accessToken() {
    final cached = _accessToken;
    if (cached != null && DateTime.now().isBefore(_renewAt)) return Future.value(cached);
    // Concurrent callers share one request. Two assertions signed in the same second are identical,
    // and Unico refuses a reused JWT (error 1.2.7).
    return _pending ??= _requestToken().whenComplete(() => _pending = null);
  }

  Future<Map<String, dynamic>> _call(String method, String path, [Map<String, dynamic>? body]) async {
    final request = http.Request(method, Uri.parse('${hosts.api}$path'))
      ..headers['Authorization'] = 'Bearer ${await accessToken()}'
      ..headers['Content-Type'] = 'application/json';
    if (body != null) request.body = jsonEncode(body);
    return _parse(await request.send().then(http.Response.fromStream).timeout(_timeout));
  }

  // https://developer.unico.io/developers/api-reference/post-processes → { process }
  Future<Map<String, dynamic>> createProcess(Map<String, dynamic> body) => _call('POST', '/client/v1/process', body);

  // https://developer.unico.io/developers/api-reference/get-process → { process }
  Future<Map<String, dynamic>> getProcess(String id) async => _call('GET', '/client/v1/process/${_processId(id)}');

  // https://developer.unico.io/developers/api-reference/get-selfie → { fileContents, contentType }
  Future<Map<String, dynamic>> getSelfie(String id) async =>
      _call('GET', '/client/v1/process/${_processId(id)}/selfie');

  // https://developer.unico.io/developers/api-reference/get-evidence-set → { fileContents, contentType }
  // `contentType` comes back as `x-pdf`; `fileContents` is a base64 PDF.
  Future<Map<String, dynamic>> getEvidenceSet(String id) async =>
      _call('GET', '/client/v1/process/${_processId(id)}/evidenceset');
}

// Any non-2xx answer, or a 2xx one that isn't a JSON object, surfaces as a UnicoError with the body as sent.
Map<String, dynamic> _parse(http.Response res) {
  // Decoded as UTF-8 whatever the Content-Type says: package:http falls back to Latin-1 when there is no charset.
  final text = utf8.decode(res.bodyBytes, allowMalformed: true);
  if (res.statusCode < 200 || res.statusCode > 299) throw UnicoError(res.statusCode, text);
  try {
    return jsonDecode(text) as Map<String, dynamic>;
  } on Object {
    throw UnicoError(res.statusCode, text);
  }
}
