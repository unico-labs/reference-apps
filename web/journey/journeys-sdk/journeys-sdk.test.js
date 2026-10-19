import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { startApp } from '../../test/fake-unico.js';

let app;

before(async () => {
  app = await startApp();
});

after(() => app.close());

const person = (flow = 'idlive_r2') =>
  new URLSearchParams({ flow, duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909', journey: 'journeys-sdk' });

test('renders the journey page with the process id, its token and the environment', async () => {
  const res = await app.post('/process', person());
  const page = await res.text();

  assert.equal(res.status, 200);
  assert.match(page, /data-process-id="abc-123"/);
  assert.match(page, /data-token="process-token"/);
  assert.match(page, /data-env="uat"/);
  assert.match(page, /"unico-journey-sdk": "\/journeys-sdk\/unico-journey-sdk\.js"/);
  assert.match(page, /import \{ ByUnicoSDK \} from 'unico-journey-sdk';/);
});

test('serves unico-journey-sdk from node_modules as an ES module', async () => {
  const res = await app.get('/journeys-sdk/unico-journey-sdk.js');

  assert.match(res.headers.get('content-type'), /^text\/javascript/);
  assert.match(await res.text(), /export\{.*as ByUnicoSDK/);
});

test('names the mode Journeys SDK on the form', async () => {
  const page = await (await app.get('/')).text();

  assert.match(page, /value="journeys-sdk"[^>]*\/> Journeys SDK<\/label>/);
});

test('shows the journey in progress behind the widget, with the flow and the process', async () => {
  const page = await (await app.post('/process', person())).text();

  assert.match(page, /<h1[^>]*>Journey in progress<\/h1>/);
  assert.match(page, /<dd><code>idlive_r2<\/code><\/dd>/);
  assert.match(page, /<dd><code>abc-123<\/code><\/dd>/);
  assert.match(page, /<dd>Journeys SDK<\/dd>/);
  assert.match(page, /<a class="button secondary" href="\/">Cancel test<\/a>/);
});

test('has a not finished state that starts a new test when the widget is closed', async () => {
  const page = await (await app.post('/process', person())).text();

  assert.match(page, /<section id="closed"[^>]*hidden/);
  assert.match(page, /Journey not finished/);
  assert.match(page, /<a class="button" href="\/">Start a new test<\/a>/);
  assert.doesNotMatch(page, /Open journey again/);
});
