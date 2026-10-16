import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart' as jwt;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart';

import '../api/unico.dart';

AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateKeys() {
  final random = FortunaRandom()
    ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (_) => Random.secure().nextInt(256)))));
  final generator = RSAKeyGenerator()
    ..init(ParametersWithRandom(RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64), random));
  return generator.generateKeyPair();
}

void main() {
  final keys = generateKeys();
  late HttpServer fake;
  late String baseUrl;
  late List<Map<String, String>> tokenRequests;
  late List<List<String>> apiRequests;
  late int tokenStatus;

  setUp(() async {
    tokenRequests = [];
    apiRequests = [];
    tokenStatus = 200;
    fake = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    baseUrl = 'http://127.0.0.1:${fake.port}';
    fake.listen((request) async {
      final body = await utf8.decodeStream(request);
      final path = request.uri.path;
      final (int status, String contentType, String payload) answer;
      if (path == '/oauth2/token') {
        tokenRequests.add(Uri.splitQueryString(body));
        answer = tokenStatus == 200
            ? (
                200,
                'application/json',
                '{"access_token":"token-${tokenRequests.length}","token_type":"Bearer","expires_in":3600}',
              )
            : (tokenStatus, 'application/json', '{"error":{"code":"1.2.21","message":"wrong private key"}}');
      } else {
        apiRequests.add([request.method, path, request.headers.value('authorization') ?? '', body]);
        answer = switch ('${request.method} $path') {
          'POST /client/v1/process' => (
            200,
            'application/json',
            '{"process":{"id":"abc-123","webAppToken":"web-app-token"}}',
          ),
          'GET /client/v1/process/abc-123' => (
            200,
            'application/json',
            '{"process":{"id":"abc-123","state":"PROCESS_STATE_FINISHED"}}',
          ),
          'GET /client/v1/process/abc-123/selfie' => (
            200,
            'application/json',
            '{"fileContents":"/9j/4AAQ","contentType":"image/jpeg"}',
          ),
          'GET /client/v1/process/abc-123/evidenceset' => (
            200,
            'application/json',
            '{"fileContents":"JVBERi0xLjMN","contentType":"x-pdf"}',
          ),
          'GET /client/v1/process/behind-gateway' => (502, 'text/html', '<html>Bad Gateway</html>'),
          _ => (
            404,
            'application/json',
            '{"code":5,"message":"error getting process: rpc error: code = NotFound desc = process not found"}',
          ),
        };
      }
      final (status, contentType, payload) = answer;
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.parse(contentType)
        ..write(payload);
      await request.response.close();
    });
  });

  tearDown(() => fake.close(force: true));

  Unico unico([Hosts? hosts]) => Unico(
    serviceAccount: 'my-account@abc123.iam.acesso.io',
    privateKey: jwt.RSAPrivateKey.raw(keys.privateKey),
    hosts: hosts ?? Hosts(identity: baseUrl, api: baseUrl),
  );

  Future<UnicoError> unicoError(Future<Object?> call) async {
    try {
      await call;
    } on UnicoError catch (e) {
      return e;
    }
    throw TestFailure('expected a UnicoError');
  }

  Map<String, dynamic> decode(String part) => jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(part))));

  test('exchanges a signed RS256 JWT for an access token', () async {
    await unico().getProcess('abc-123');

    final params = tokenRequests.single;
    expect(params['grant_type'], 'urn:ietf:params:oauth:grant-type:jwt-bearer');
    final assertion = params['assertion']!;
    final [header, payload, _] = assertion.split('.');
    expect(decode(header)['alg'], 'RS256');
    final claims = decode(payload);
    expect(claims.keys.toSet(), {'iss', 'aud', 'scope', 'iat', 'exp'});
    expect(claims['iss'], 'my-account@abc123.iam.acesso.io');
    expect(claims['aud'], baseUrl);
    expect(claims['scope'], '*');
    expect((claims['exp'] as int) - (claims['iat'] as int), 3600);
    expect(() => jwt.JWT.verify(assertion, jwt.RSAPublicKey.raw(keys.publicKey)), returnsNormally);
  });

  test('creates a process with the bearer token and returns the body as sent', () async {
    final body = {'flow': 'idlive_r2', 'callbackUri': '/'};

    final result = await unico().createProcess(body);

    expect((result['process'] as Map)['webAppToken'], 'web-app-token');
    expect(apiRequests.single, ['POST', '/client/v1/process', 'Bearer token-1', jsonEncode(body)]);
  });

  test('concurrent calls share one token request and later calls reuse it', () async {
    final client = unico();
    await Future.wait([client.getProcess('abc-123'), client.getSelfie('abc-123')]);
    await client.getEvidenceSet('abc-123');

    expect(tokenRequests, hasLength(1));
    expect(apiRequests.map((r) => r[1]).toList()..sort(), [
      '/client/v1/process/abc-123',
      '/client/v1/process/abc-123/evidenceset',
      '/client/v1/process/abc-123/selfie',
    ]);
  });

  test('an API error carries the status and body as returned', () async {
    final error = await unicoError(unico().getProcess('missing'));

    expect(error.status, 404);
    expect(
      error.body,
      '{"code":5,"message":"error getting process: rpc error: code = NotFound desc = process not found"}',
    );
  });

  test('a non-JSON error body comes back as text', () async {
    final error = await unicoError(unico().getProcess('behind-gateway'));

    expect(error.status, 502);
    expect(error.body, '<html>Bad Gateway</html>');
  });

  test('a token error stops before the API call', () async {
    tokenStatus = 401;

    final error = await unicoError(unico().getProcess('abc-123'));

    expect(error.status, 401);
    expect(error.body, contains('1.2.21'));
    expect(apiRequests, isEmpty);
  });

  test('a malformed process id is refused before anything is sent', () async {
    await expectLater(unico().getSelfie('../token'), throwsA(isA<InvalidInputError>()));

    expect(tokenRequests, isEmpty);
    expect(apiRequests, isEmpty);
  });

  test('a network failure surfaces as a ClientException', () async {
    const nothingListening = Hosts(identity: 'http://127.0.0.1:1', api: 'http://127.0.0.1:1');

    await expectLater(unico(nothingListening).getProcess('abc-123'), throwsA(isA<http.ClientException>()));
  });
}
