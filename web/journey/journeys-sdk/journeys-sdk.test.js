import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { startApp } from '../../test/fake-unico.js';

let app;

before(async () => {
  app = await startApp();
});

after(() => app.close());

const person = () =>
  new URLSearchParams({ duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909', journey: 'journeys-sdk' });

test('renders the journey page with the process id, its token and the environment', async () => {
  const res = await app.post('/flows/idlive_r2', person());
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
