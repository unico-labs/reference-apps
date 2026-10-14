import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
import { createServer } from 'node:http';
import { after, before, beforeEach, test } from 'node:test';
import { createUnico, InvalidInputError, UnicoError } from '../src/unico.js';

const { privateKey, publicKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  publicKeyEncoding: { type: 'spki', format: 'pem' },
});

let fake;
let baseUrl;
let tokenRequests;
let apiRequests;
let tokenResponse;

const decode = (part) => JSON.parse(Buffer.from(part, 'base64url').toString());

before(async () => {
  fake = createServer(async (req, res) => {
    let body = '';
    for await (const chunk of req) body += chunk;

    if (req.url === '/oauth2/token') {
      tokenRequests.push(new URLSearchParams(body));
      res.writeHead(tokenResponse.status, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify(tokenResponse.body(tokenRequests.length)));
    }

    apiRequests.push({ method: req.method, url: req.url, authorization: req.headers.authorization, body });
    if (req.url === '/client/v1/process/behind-gateway') {
      res.writeHead(502, { 'Content-Type': 'text/html' });
      return res.end('<html>Bad Gateway</html>');
    }
    const routes = {
      'POST /client/v1/process': [
        200,
        { process: { id: 'abc-123', userRedirectUrl: 'https://cadastro.uat.unico.app/x' } },
      ],
      'GET /client/v1/process/abc-123': [200, { process: { id: 'abc-123', state: 'PROCESS_STATE_FINISHED' } }],
      'GET /client/v1/process/abc-123/selfie': [200, { fileContents: '/9j/4AAQ', contentType: 'image/jpeg' }],
      'GET /client/v1/process/abc-123/evidenceset': [
        200,
        { fileContents: 'JVBERi0xLjMN', contentType: 'application/pdf' },
      ],
    };
    const [status, payload] = routes[`${req.method} ${req.url}`] ?? [404, { code: 5, message: 'process not found' }];
    res.writeHead(status, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(payload));
  });
  await new Promise((resolve) => fake.listen(0, resolve));
  baseUrl = `http://localhost:${fake.address().port}`;
});

after(() => fake.close());

beforeEach(() => {
  tokenRequests = [];
  apiRequests = [];
  tokenResponse = {
    status: 200,
    body: (n) => ({ access_token: `token-${n}`, token_type: 'Bearer', expires_in: 3600 }),
  };
});

const unico = () =>
  createUnico({
    serviceAccount: 'my-account@abc123.iam.acesso.io',
    privateKey,
    hosts: { identity: baseUrl, api: baseUrl },
  });

test('exchanges a signed RS256 JWT for an access token', async () => {
  await unico().getProcess('abc-123');

  const params = tokenRequests[0];
  assert.equal(params.get('grant_type'), 'urn:ietf:params:oauth:grant-type:jwt-bearer');

  const [header, claims, signature] = params.get('assertion').split('.');
  assert.deepEqual(decode(header), { alg: 'RS256', typ: 'JWT' });
  assert.ok(verify('RSA-SHA256', Buffer.from(`${header}.${claims}`), publicKey, Buffer.from(signature, 'base64url')));

  const { iss, aud, scope, iat, exp, ...rest } = decode(claims);
  assert.equal(iss, 'my-account@abc123.iam.acesso.io');
  assert.equal(aud, baseUrl);
  assert.equal(scope, '*');
  assert.equal(exp - iat, 3600);
  assert.deepEqual(rest, {});
});

test('creates a process sending the body as JSON with the bearer token', async () => {
  const body = { flow: 'idlive_r2', callbackUri: 'http://localhost:8080' };

  const { process } = await unico().createProcess(body);

  assert.deepEqual(apiRequests[0], {
    method: 'POST',
    url: '/client/v1/process',
    authorization: 'Bearer token-1',
    body: JSON.stringify(body),
  });
  assert.equal(process.id, 'abc-123');
});

test('gets a process, its selfie and its evidence set', async () => {
  const client = unico();

  const { process } = await client.getProcess('abc-123');
  const selfie = await client.getSelfie('abc-123');
  const evidenceSet = await client.getEvidenceSet('abc-123');

  assert.equal(process.state, 'PROCESS_STATE_FINISHED');
  assert.deepEqual(selfie, { fileContents: '/9j/4AAQ', contentType: 'image/jpeg' });
  assert.deepEqual(evidenceSet, { fileContents: 'JVBERi0xLjMN', contentType: 'application/pdf' });
});

test('reuses the token while it is far from expiring', async () => {
  const client = unico();

  await client.getProcess('abc-123');
  await client.getSelfie('abc-123');

  assert.equal(tokenRequests.length, 1);
});

test('renews the token when 10 minutes or less remain', async () => {
  tokenResponse.body = (n) => ({ access_token: `token-${n}`, token_type: 'Bearer', expires_in: 600 });
  const client = unico();

  await client.getProcess('abc-123');
  await client.getProcess('abc-123');

  assert.equal(tokenRequests.length, 2);
  assert.equal(apiRequests[1].authorization, 'Bearer token-2');
});

const rejectsWith = (promise, status, body) =>
  assert.rejects(promise, (err) => {
    assert.ok(err instanceof UnicoError);
    assert.equal(err.status, status);
    assert.deepEqual(err.body, body);
    return true;
  });

test('throws API errors with their status and body', async () => {
  await rejectsWith(unico().getProcess('missing'), 404, { code: 5, message: 'process not found' });
});

test('throws a token failure with the identity status and body', async () => {
  tokenResponse = { status: 401, body: () => ({ code: '1.2.22', message: 'invalid claim' }) };

  await rejectsWith(unico().getProcess('abc-123'), 401, { code: '1.2.22', message: 'invalid claim' });
  assert.equal(apiRequests.length, 0);
});

test('keeps a non-JSON error body as text', async () => {
  await rejectsWith(unico().getProcess('behind-gateway'), 502, '<html>Bad Gateway</html>');
});

test('lets a network failure through as is', async () => {
  const offline = createUnico({
    serviceAccount: 'my-account@abc123.iam.acesso.io',
    privateKey,
    hosts: { identity: 'http://localhost:1', api: 'http://localhost:1' },
  });

  await assert.rejects(offline.getProcess('abc-123'), (err) => {
    assert.ok(!(err instanceof UnicoError));
    assert.equal(err.message, 'fetch failed');
    return true;
  });
});

test('rejects a malformed process id without calling the API', async () => {
  const client = unico();
  const invalid = (err) => err instanceof InvalidInputError && err.message === 'invalid process id';

  await assert.rejects(client.getProcess('../../oauth2'), invalid);
  await assert.rejects(client.getSelfie('../../oauth2'), invalid);
  await assert.rejects(client.getEvidenceSet('../../oauth2'), invalid);
  assert.equal(apiRequests.length, 0);
});
