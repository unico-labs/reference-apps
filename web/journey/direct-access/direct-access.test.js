import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { startApp } from '../../test/fake-unico.js';

let app;

before(async () => {
  app = await startApp();
});

after(() => app.close());

const person = () =>
  new URLSearchParams({ duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909', journey: 'direct-access' });

test('redirects the browser to the journey', async () => {
  const res = await app.post('/flows/idlive_r2', person());

  assert.equal(res.status, 303);
  assert.equal(res.headers.get('location'), 'https://cadastro.uat.unico.app/abc');
});

test('redirects to userRedirectUrl exactly as returned', async () => {
  const res = await app.post('/flows/idtrust_r2', person());

  assert.equal(res.headers.get('location'), 'https://cadastro.uat.unico.app/flow?id=abc-123&q=%zz|');
});
