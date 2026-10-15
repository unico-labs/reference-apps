import assert from 'node:assert/strict';
import { generateKeyPairSync } from 'node:crypto';
import { createServer } from 'node:http';
import { after, before, beforeEach, test } from 'node:test';
import { createUnico } from '../api/unico.js';
import { createApp } from '../app.js';

const { privateKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  publicKeyEncoding: { type: 'spki', format: 'pem' },
});

const pdf = Buffer.from('%PDF-1.3\n%%EOF\n');

let fakeUnico;
let server;
let publicUrl;
let created;

before(async () => {
  const routes = {
    'POST /oauth2/token': () => [200, { access_token: 'token', token_type: 'Bearer', expires_in: 3600 }],
    'POST /client/v1/process': (body) => {
      created.push(body);
      if (body.flow === 'id_r2') return [400, { code: 3, message: '<script>alert(1)</script>' }];
      const userRedirectUrl =
        body.flow === 'idtrust_r2'
          ? 'https://cadastro.uat.unico.app/flow?id=abc-123&q=%zz|'
          : 'https://cadastro.uat.unico.app/abc';
      return [200, { process: { id: 'abc-123', userRedirectUrl } }];
    },
    'GET /client/v1/process/abc-123': () => [200, { process: { id: 'abc-123', state: 'PROCESS_STATE_FINISHED' } }],
    'GET /client/v1/process/abc-123/selfie': () => [200, { fileContents: '/9j/4AAQ', contentType: 'image/jpeg' }],
    'GET /client/v1/process/abc-123/evidenceset': () => [
      200,
      { fileContents: pdf.toString('base64'), contentType: 'x-pdf' },
    ],
  };

  fakeUnico = createServer(async (req, res) => {
    let body = '';
    for await (const chunk of req) body += chunk;
    const route = routes[`${req.method} ${req.url}`];
    const [status, payload] = route
      ? route(body && req.headers['content-type'] === 'application/json' ? JSON.parse(body) : body)
      : [404, { code: 5, message: 'error getting process: rpc error: code = NotFound desc = process not found' }];
    res.writeHead(status, { 'Content-Type': 'application/json' }).end(JSON.stringify(payload));
  });
  await new Promise((resolve) => fakeUnico.listen(0, resolve));
  const fakeUrl = `http://localhost:${fakeUnico.address().port}`;

  let handler;
  server = createServer((req, res) => handler(req, res));
  await new Promise((resolve) => server.listen(0, resolve));
  publicUrl = `http://localhost:${server.address().port}`;

  const unico = createUnico({
    serviceAccount: 'my-account@abc123.iam.acesso.io',
    privateKey,
    hosts: { identity: fakeUrl, api: fakeUrl },
  });
  handler = createApp({ unico, publicUrl });
});

after(() => {
  server.close();
  fakeUnico.close();
});

beforeEach(() => {
  created = [];
});

const get = (path, headers = {}) => fetch(`${publicUrl}${path}`, { headers, redirect: 'manual' });

const post = (path, body, headers = {}) =>
  fetch(`${publicUrl}${path}`, {
    method: 'POST',
    body,
    headers: { Origin: publicUrl, ...headers },
    redirect: 'manual',
  });

const person = () => new URLSearchParams({ duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909' });

test('lists the sign-up flows of every region by default', async () => {
  const res = await get('/');
  const page = await res.text();

  assert.equal(res.status, 200);
  assert.equal(page.match(/href="\/flows\/[^"?]+"/g).length, 16);
});

test('filters flows by use case and region', async () => {
  const page = await (await get('/flows?group=step-up&region=brazil')).text();

  assert.match(page, /No step-up flows for this region/);
});

test('shows the document fields only on Face Document Match flows', async () => {
  const docs = await (await get('/flows/idunicodocs_r2')).text();
  const live = await (await get('/flows/idlive_r2')).text();

  assert.match(docs, /name="documentFiles"/);
  assert.doesNotMatch(live, /name="documentFiles"/);
});

test('answers 404 for an unknown flow', async () => {
  const res = await get('/flows/nope');

  assert.equal(res.status, 404);
});

test('creates the process and redirects the browser to the journey', async () => {
  const res = await post('/flows/idlive_r2', person());

  assert.equal(res.status, 303);
  assert.equal(res.headers.get('location'), 'https://cadastro.uat.unico.app/abc');
  assert.match(res.headers.get('set-cookie'), /^unico_process_id=abc-123; Path=\/; HttpOnly; SameSite=Lax/);
  assert.deepEqual(created[0], {
    flow: 'idlive_r2',
    callbackUri: `${publicUrl}/result`,
    person: { duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909' },
  });
});

test('redirects to userRedirectUrl exactly as returned', async () => {
  const res = await post('/flows/idtrust_r2', person());

  assert.equal(res.headers.get('location'), 'https://cadastro.uat.unico.app/flow?id=abc-123&q=%zz|');
});

test('does not name the framework in its responses', async () => {
  const res = await get('/');

  assert.equal(res.headers.get('x-powered-by'), null);
});

test('sends uploaded document files as base64', async () => {
  const form = new FormData();
  form.set('duiType', 'DUI_TYPE_BR_CPF');
  form.set('duiValue', '12345678909');
  form.set('documentPurpose', 'DOCUMENT_PURPOSE_ONBOARDING');
  form.append('documentFiles', new Blob([Buffer.from('front')]), 'front.png');

  const res = await post('/flows/idunicodocs_r2', form);

  assert.equal(res.status, 303);
  assert.deepEqual(created[0].document, {
    purpose: 'DOCUMENT_PURPOSE_ONBOARDING',
    files: [{ data: Buffer.from('front').toString('base64') }],
  });
});

test('shows a Create Process error raw on the form, escaped', async () => {
  const res = await post('/flows/id_r2', person());
  const page = await res.text();

  assert.equal(res.status, 400);
  assert.match(page, /HTTP 400/);
  assert.match(page, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
  assert.doesNotMatch(page, /<script>alert/);
});

test('refuses a form posted from another site', async () => {
  const res = await post('/flows/idlive_r2', person(), { Origin: 'https://evil.example' });

  assert.equal(res.status, 403);
  assert.equal(created.length, 0);
});

test('shows the process and the selfie on the result page', async () => {
  const page = await (await get('/result', { Cookie: 'unico_process_id=abc-123' })).text();

  assert.match(page, /PROCESS_STATE_FINISHED/);
  assert.match(page, /src="data:image\/jpeg;base64,\/9j\/4AAQ"/);
  assert.match(page, /href="\/result\/evidenceset"/);
});

test('says there is no process when the cookie is missing', async () => {
  const page = await (await get('/result')).text();

  assert.match(page, /No process in this browser yet/);
});

test('says there is no process when the evidence set is asked without the cookie', async () => {
  const res = await get('/result/evidenceset');

  assert.equal(res.status, 404);
  assert.match(await res.text(), /No process in this browser yet/);
});

test('answers 400 to a form post that cannot be parsed', async () => {
  const res = await post('/flows/idlive_r2', 'not a form', { 'Content-Type': 'text/plain' });

  assert.equal(res.status, 400);
  assert.equal(created.length, 0);
});

test('points at PUBLIC_URL when a form comes from another address', async () => {
  const res = await post('/flows/idlive_r2', person(), { Origin: 'http://127.0.0.1:3000' });

  assert.equal(res.status, 403);
  assert.match(await res.text(), new RegExp(`Open the app at ${publicUrl}`));
});

test('serves the evidence set as a PDF', async () => {
  const res = await get('/result/evidenceset', { Cookie: 'unico_process_id=abc-123' });

  assert.equal(res.headers.get('content-type'), 'application/pdf');
  assert.deepEqual(Buffer.from(await res.arrayBuffer()), pdf);
});
