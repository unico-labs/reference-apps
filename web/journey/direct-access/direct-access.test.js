import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { startApp } from '../../test/fake-unico.js';

let app;

before(async () => {
  app = await startApp();
});

after(() => app.close());

const person = (flow = 'idlive_r2') =>
  new URLSearchParams({ flow, duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909', journey: 'direct-access' });

test('redirects the browser to the journey', async () => {
  const res = await app.post('/process', person());

  assert.equal(res.status, 303);
  assert.equal(res.headers.get('location'), 'https://cadastro.uat.unico.app/abc');
});

test('redirects to userRedirectUrl exactly as returned', async () => {
  const res = await app.post('/process', person('idtrust_r2'));

  assert.equal(res.headers.get('location'), 'https://cadastro.uat.unico.app/flow?id=abc-123&q=%zz|');
});

test('names the mode Redirect on the form', async () => {
  const page = await (await app.get('/')).text();

  assert.match(page, /value="direct-access"[^>]*\/> Redirect<\/label>/);
});
