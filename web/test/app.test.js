import assert from 'node:assert/strict';
import { after, before, beforeEach, test } from 'node:test';
import { journeys, pdf, startApp } from './fake-unico.js';

let app;

before(async () => {
  app = await startApp();
});

after(() => app.close());

beforeEach(() => {
  app.created.length = 0;
});

const person = (journey = journeys[0]) =>
  new URLSearchParams({ duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909', journey });

test('lists the sign-up flows of every region by default', async () => {
  const res = await app.get('/');
  const page = await res.text();

  assert.equal(res.status, 200);
  assert.equal(page.match(/href="\/flows\/[^"?]+"/g).length, 16);
});

test('filters flows by use case and region', async () => {
  const page = await (await app.get('/flows?group=step-up&region=brazil')).text();

  assert.match(page, /No step-up flows for this region/);
});

test('shows the document fields only on Face Document Match flows', async () => {
  const docs = await (await app.get('/flows/idunicodocs_r2')).text();
  const live = await (await app.get('/flows/idlive_r2')).text();

  assert.match(docs, /name="documentFiles"/);
  assert.doesNotMatch(live, /name="documentFiles"/);
});

test('offers one button per journey mode on the form', async () => {
  const page = await (await app.get('/flows/idlive_r2')).text();

  assert.deepEqual(
    [...page.matchAll(/<button[^>]*name="journey" value="([^"]+)"/g)].map((match) => match[1]),
    journeys,
  );
});

test('answers 404 for an unknown flow', async () => {
  const res = await app.get('/flows/nope');

  assert.equal(res.status, 404);
});

test('creates the process with the callbackUri and remembers its id', async () => {
  const res = await app.post('/flows/idlive_r2', person());

  assert.match(res.headers.get('set-cookie'), /^unico_process_id=abc-123; Path=\/; HttpOnly; SameSite=Lax/);
  assert.deepEqual(app.created[0], {
    flow: 'idlive_r2',
    callbackUri: `${app.publicUrl}/result`,
    person: { duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909' },
  });
});

test('refuses an unknown journey mode before creating the process', async () => {
  const res = await app.post('/flows/idlive_r2', person('__proto__'));

  assert.equal(res.status, 400);
  assert.equal(app.created.length, 0);
});

test('does not name the framework in its responses', async () => {
  const res = await app.get('/');

  assert.equal(res.headers.get('x-powered-by'), null);
});

test('sends uploaded document files as base64', async () => {
  const form = new FormData();
  form.set('duiType', 'DUI_TYPE_BR_CPF');
  form.set('duiValue', '12345678909');
  form.set('documentPurpose', 'DOCUMENT_PURPOSE_ONBOARDING');
  form.set('journey', journeys[0]);
  form.append('documentFiles', new Blob([Buffer.from('front')]), 'front.png');

  await app.post('/flows/idunicodocs_r2', form);

  assert.deepEqual(app.created[0].document, {
    purpose: 'DOCUMENT_PURPOSE_ONBOARDING',
    files: [{ data: Buffer.from('front').toString('base64') }],
  });
});

test('shows a Create Process error raw on the form, escaped', async () => {
  const res = await app.post('/flows/id_r2', person());
  const page = await res.text();

  assert.equal(res.status, 400);
  assert.match(page, /HTTP 400/);
  assert.match(page, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
  assert.doesNotMatch(page, /<script>alert/);
});

test('refuses a form posted from another site', async () => {
  const res = await app.post('/flows/idlive_r2', person(), { Origin: 'https://evil.example' });

  assert.equal(res.status, 403);
  assert.equal(app.created.length, 0);
});

test('shows the process and the selfie on the result page', async () => {
  const page = await (await app.get('/result', { Cookie: 'unico_process_id=abc-123' })).text();

  assert.match(page, /PROCESS_STATE_FINISHED/);
  assert.match(page, /src="data:image\/jpeg;base64,\/9j\/4AAQ"/);
  assert.match(page, /href="\/result\/evidenceset"/);
});

test('says there is no process when the cookie is missing', async () => {
  const page = await (await app.get('/result')).text();

  assert.match(page, /No process in this browser yet/);
});

test('says there is no process when the evidence set is asked without the cookie', async () => {
  const res = await app.get('/result/evidenceset');

  assert.equal(res.status, 404);
  assert.match(await res.text(), /No process in this browser yet/);
});

test('answers 400 to a form post that cannot be parsed', async () => {
  const res = await app.post('/flows/idlive_r2', 'not a form', { 'Content-Type': 'text/plain' });

  assert.equal(res.status, 400);
  assert.equal(app.created.length, 0);
});

test('points at PUBLIC_URL when a form comes from another address', async () => {
  const res = await app.post('/flows/idlive_r2', person(), { Origin: 'http://127.0.0.1:3000' });

  assert.equal(res.status, 403);
  assert.match(await res.text(), new RegExp(`Open the app at ${app.publicUrl}`));
});

test('serves the evidence set as a PDF', async () => {
  const res = await app.get('/result/evidenceset', { Cookie: 'unico_process_id=abc-123' });

  assert.equal(res.headers.get('content-type'), 'application/pdf');
  assert.deepEqual(Buffer.from(await res.arrayBuffer()), pdf);
});
