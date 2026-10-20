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

const person = (journey = journeys[0], flow = 'idlive_r2') =>
  new URLSearchParams({ flow, duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909', journey });

test('opens on a welcome page with the server configuration and a link to the form', async () => {
  const res = await app.get('/');
  const page = await res.text();

  assert.equal(res.status, 200);
  assert.match(page, /See how a Unico integration works/);
  assert.match(page, /Run a real flow in UAT\./);
  assert.match(page, /<dt>Service account<\/dt><dd><code>my-account<\/code><\/dd>/);
  assert.match(page, /<dt>Tenant ID<\/dt><dd><code>abc123<\/code><\/dd>/);
  assert.match(page, /<dt>Environment<\/dt><dd><code>UAT<\/code><\/dd>/);
  assert.match(page, /<a class="button" href="\/run">Get started<\/a>/);
  assert.doesNotMatch(page, /PRIVATE KEY/);
});

test('says on the welcome page that Unico gave the server a token', async () => {
  const page = await (await app.get('/')).text();

  assert.match(page, /<dt>Status<\/dt><dd><span class="pill">[\s\S]*Ready<\/span><\/dd>/);
});

test('shows on the welcome page the token error raw when Unico refuses the credentials', async () => {
  const refused = await startApp({ token: [401, { error: 'invalid_grant', error_description: '<b>bad</b>' }] });
  const page = await (await refused.get('/')).text();
  refused.close();

  assert.doesNotMatch(page, /Ready</);
  assert.match(page, /Couldn.t get a token/);
  assert.match(page, /HTTP 401/);
  assert.match(page, /&lt;b&gt;bad&lt;\/b&gt;/);
  assert.match(
    page,
    /Check <code>UNICO_ENV<\/code>, <code>UNICO_SERVICE_ACCOUNT<\/code> and <code>UNICO_PRIVATE_KEY_PATH<\/code>/,
  );
  assert.doesNotMatch(page, /<span class="pill"><svg/);
});

test('says on the welcome page that the credentials stay on the server', async () => {
  const page = await (await app.get('/')).text();

  assert.match(page, /<b>Credentials stay on your server<\/b>/);
  assert.match(page, /The server reads them from its <code>.env<\/code>\. Nothing to enter here\./);
});

test('asks for the flow by name on the form', async () => {
  const res = await app.get('/run');
  const page = await res.text();

  assert.equal(res.status, 200);
  assert.match(page, /<input[^>]*name="flow"[^>]*required/);
  assert.match(page, /name="flow"[^>]*placeholder="e\.g\. idlive_r2"/);
});

test('only the flow is required', async () => {
  const page = await (await app.get('/run')).text();

  assert.equal([...page.matchAll(/\srequired[\s/>]/g)].length, 1);
  assert.equal([...page.matchAll(/class="req"/g)].length, 1);
});

test('shows the environment and the service account in the header', async () => {
  const page = await (await app.get('/run')).text();

  assert.match(page, /UAT · my-account/);
});

test('names the app Run a flow in the header', async () => {
  const page = await (await app.get('/run')).text();

  assert.match(page, /<a class="bar-title" href="\/run">Run a flow<\/a>/);
});

test('leaves the demo notice out of the form', async () => {
  const page = await (await app.get('/run')).text();

  assert.doesNotMatch(page, /class="notice"/);
  assert.doesNotMatch(page, /Updates as you type|Web only|Start test stays disabled/);
});

test('offers one choice per journey mode on the form', async () => {
  const page = await (await app.get('/run')).text();

  assert.deepEqual(
    [...page.matchAll(/<input[^>]*type="radio" name="journey" value="([^"]+)"/g)].map((match) => match[1]).sort(),
    [...journeys].sort(),
  );
});

test('prefills a step-up on a process from the link on the result page', async () => {
  const page = await (await app.get('/run?references=abc-123')).text();

  assert.match(page, /name="withReferences"[^>]*checked/);
  assert.match(page, /name="referenceProcessId"[^>]*value="abc-123"/);
});

test('shows the request preview in the page, not in Customize', async () => {
  const page = await (await app.get('/run')).text();

  assert.ok(page.indexOf('id="preview"') < page.indexOf('<dialog'));
});

test('offers the useCase values from the docs in a select', async () => {
  const page = await (await app.get('/run')).text();

  assert.match(
    page,
    /<select name="useCase">\s*<option[^>]*>USE_CASE_LOGIN<\/option>\s*<option[^>]*>USE_CASE_FIN_TRANSACTIONS<\/option>/,
  );
});

test('fills the reference with the last process without turning it on', async () => {
  const page = await (await app.get('/run', { Cookie: 'unico_process_id=abc-123' })).text();

  assert.match(page, /name="referenceProcessId"[^>]*value="abc-123"/);
  assert.match(page, /Filled from your last test/);
  assert.doesNotMatch(page, /name="withReferences"[^>]*checked/);
});

test('labels each field in words, with its name in the Create Process body', async () => {
  const page = await (await app.get('/run')).text();
  const labels = [...page.matchAll(/<span class="label">([^<]+)<code class="api">([^<]+)<\/code>/g)].map((m) => [
    m[1].trim(),
    m[2],
  ]);

  assert.deepEqual(labels, [
    ['Flow', 'flow'],
    ['Document type', 'person.duiType'],
    ['Document number', 'person.duiValue'],
    ['Name', 'person.friendlyName'],
    ['Email', 'person.email'],
    ['Phone', 'person.phone'],
    ['Expires in', 'expiresIn'],
    ['Purpose', 'purpose'],
    ['Document image', 'document'],
    ['Document files', 'document.files'],
    ['Document purpose', 'document.purpose'],
    ['Use case and reference', 'useCase, references'],
    ['Use case', 'useCase'],
    ['Reference process ID', 'references'],
    ['Contextualization', 'contextualization'],
    ['Company name', 'company_name'],
    ['Currency', 'currency'],
    ['Price', 'price'],
    ['Reason language', 'locale'],
    ['Reason', 'locale.{language}.reason'],
  ]);
});

test('serves the body builder to the request preview', async () => {
  const res = await app.get('/flows/flows.js');

  assert.match(res.headers.get('content-type'), /javascript/);
  assert.match(await res.text(), /export function buildProcessBody/);
});

test('answers 404 for an unknown page', async () => {
  const res = await app.get('/nope');

  assert.equal(res.status, 404);
});

test('creates the process with the typed flow and the callbackUri and remembers its id', async () => {
  const res = await app.post('/process', person());

  assert.match(res.headers.get('set-cookie'), /^unico_process_id=abc-123; Path=\/; HttpOnly; SameSite=Lax/);
  assert.deepEqual(app.created[0], {
    flow: 'idlive_r2',
    callbackUri: `${app.publicUrl}/result`,
    person: { duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909' },
  });
});

test('refuses an unknown journey mode before creating the process', async () => {
  const res = await app.post('/process', person('__proto__'));

  assert.equal(res.status, 400);
  assert.equal(app.created.length, 0);
});

test('does not name the framework in its responses', async () => {
  const res = await app.get('/run');

  assert.equal(res.headers.get('x-powered-by'), null);
});

test('sends uploaded document files as base64', async () => {
  const form = new FormData();
  form.set('flow', 'idunicodocs_r2');
  form.set('duiType', 'DUI_TYPE_BR_CPF');
  form.set('duiValue', '12345678909');
  form.set('withDocument', 'on');
  form.set('journey', journeys[0]);
  form.append('documentFiles', new Blob([Buffer.from('front')]), 'front.png');

  await app.post('/process', form);

  assert.deepEqual(app.created[0].document, { files: [{ data: Buffer.from('front').toString('base64') }] });
});

test('shows a Create Process error raw, escaped, and keeps what was typed', async () => {
  const res = await app.post('/process', person(journeys[0], 'not_a_flow'));
  const page = await res.text();

  assert.equal(res.status, 400);
  assert.match(page, /Couldn.t start the test/);
  assert.match(page, /HTTP 400/);
  assert.match(page, /&lt;script&gt;alert\(1\)&lt;\/script&gt;/);
  assert.doesNotMatch(page, /<script>alert/);
  assert.match(page, /name="flow"[^>]*value="not_a_flow"/);
  assert.match(page, /name="duiValue"[^>]*value="12345678909"/);
});

test('shows a Create Process error on its own screen, with the form kept hidden behind it', async () => {
  const page = await (await app.post('/process', person(journeys[0], 'not_a_flow'))).text();

  assert.match(page, /<div id="run" hidden>/);
  assert.match(page, /What you can do/);
  assert.match(page, />Try again</);
  assert.match(page, /Check the information you entered and confirm the flow is active on your account\./);
  assert.doesNotMatch(page, /id="api-error">POST \/client\/v1\/process/);
  assert.doesNotMatch(page, /Shown exactly as Unico returned it/);
  assert.doesNotMatch(page, /class="card warn"/);
  assert.match(page, /What you can do<\/p>\s*<p>Check the information you entered/);
});

test('shows the form when there is no error', async () => {
  const page = await (await app.get('/run')).text();

  assert.match(page, /<div id="run">/);
  assert.doesNotMatch(page, /Couldn.t start the test/);
});

test('refuses a form posted from another site', async () => {
  const res = await app.post('/process', person(), { Origin: 'https://evil.example' });

  assert.equal(res.status, 403);
  assert.equal(app.created.length, 0);
});

test('shows the process and the selfie on the result page', async () => {
  const page = await (await app.get('/result', { Cookie: 'unico_process_id=abc-123' })).text();

  assert.match(page, /PROCESS_STATE_FINISHED/);
  assert.match(page, /src="data:image\/jpeg;base64,\/9j\/4AAQ"/);
  assert.match(page, /href="\/result\/evidenceset"/);
});

test('leads the result page with the verdict and offers a step-up on the process', async () => {
  const page = await (await app.get('/result', { Cookie: 'unico_process_id=abc-123' })).text();

  assert.match(page, /href="\/run\?references=abc-123"/);
});

test('shows PROCESS_RESULT_OK as a green Success, with the flow and how long it took', async () => {
  const page = await (await app.get('/result', { Cookie: 'unico_process_id=abc-123' })).text();

  assert.match(page, /class="icon ok"/);
  assert.match(page, /<h1>Success<\/h1>/);
  assert.match(page, /<code>idlive_r2<\/code> · 38 s/);
  assert.match(page, /<dt>Result<\/dt><dd><code>OK<\/code><\/dd>/);
});

test('shows a negative result in red, named as the API returns it', async () => {
  const page = await (await app.get('/result', { Cookie: 'unico_process_id=def-456' })).text();

  assert.match(page, /class="icon bad"/);
  assert.match(page, /<h1>Invalid identity<\/h1>/);
});

const tones = {
  ok: ['PROCESS_RESULT_OK', 'PROCESS_RESULT_APPROVED', 'PROCESS_RESULT_AUTHENTICATED'],
  bad: [
    'PROCESS_RESULT_INVALID_IDENTITY',
    'PROCESS_RESULT_ERROR',
    'PROCESS_RESULT_NOT_APPROVED',
    'PROCESS_RESULT_NOT_LIVE',
    'PROCESS_RESULT_HIGH_RISK',
    'PROCESS_RESULT_CRITICAL_RISK',
    'PROCESS_RESULT_AUTHENTICATED_WITH_HIGH_RISK',
    'PROCESS_RESULT_AUTHENTICATED_WITH_CRITICAL_RISK',
    'PROCESS_RESULT_AUTHENTICATED_WITH_EXTREME_RISK',
  ],
  '': ['PROCESS_RESULT_INCONCLUSIVE', 'PROCESS_RESULT_RETRY', 'PROCESS_RESULT_EXPIRED', 'PROCESS_RESULT_UNSPECIFIED'],
};

for (const [tone, results] of Object.entries(tones)) {
  for (const result of results) {
    test(`colours ${result} as ${tone || 'neutral'}`, async () => {
      const page = await (await app.get('/result', { Cookie: `unico_process_id=${result}` })).text();

      assert.match(page, new RegExp(`class="icon ${tone}"`));
    });
  }
}

test('lists the selfie and the evidence set as attachments', async () => {
  const page = await (await app.get('/result', { Cookie: 'unico_process_id=abc-123' })).text();

  assert.match(page, />Selfie</);
  assert.match(page, />Evidence set \(PDF\)</);
  assert.match(page, /<a href="\/result\/evidenceset" target="_blank">Open<\/a>/);
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
  const res = await app.post('/process', 'not a form', { 'Content-Type': 'text/plain' });

  assert.equal(res.status, 400);
  assert.equal(app.created.length, 0);
});

test('points at PUBLIC_URL when a form comes from another address', async () => {
  const res = await app.post('/process', person(), { Origin: 'http://127.0.0.1:3000' });

  assert.equal(res.status, 403);
  assert.match(await res.text(), new RegExp(`Open the app at ${app.publicUrl}`));
});

test('serves the evidence set as a PDF', async () => {
  const res = await app.get('/result/evidenceset', { Cookie: 'unico_process_id=abc-123' });

  assert.equal(res.headers.get('content-type'), 'application/pdf');
  assert.deepEqual(Buffer.from(await res.arrayBuffer()), pdf);
});
