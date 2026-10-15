import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { test } from 'node:test';
import { buildProcessBody, filterFlows } from '../flows/flows.js';

const flows = JSON.parse(readFileSync(new URL('../flows/flows.json', import.meta.url)));
const flow = (id) => flows.find((f) => f.id === id);
const callbackUri = 'http://localhost:3000/result';

test('filters flows by group and region', () => {
  const ids = (filter) => filterFlows(flows, filter).map((f) => f.id);

  assert.deepEqual(ids({ group: 'step-up', region: 'all' }), ['idsmart_r2', 'idsmart_tp1']);
  assert.deepEqual(ids({ group: 'sign-up', region: 'mexico' }), ['idtrust_r2-idgov', 'idtrustdocs_r2-idgov']);
  assert.equal(ids({ group: 'sign-up', region: 'all' }).length, 16);
  assert.deepEqual(ids({ group: 'step-up', region: 'brazil' }), []);
});

test('sends only the fields that were filled in', () => {
  const body = buildProcessBody(
    flow('idlive_r2'),
    { duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909', friendlyName: '', email: '', phone: '' },
    callbackUri,
  );

  assert.deepEqual(body, {
    flow: 'idlive_r2',
    callbackUri,
    person: { duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909' },
  });
});

test('adds the document files and purpose on Face Document Match flows', () => {
  const body = buildProcessBody(
    flow('idunicodocs_r2'),
    {
      duiType: 'DUI_TYPE_BR_CPF',
      duiValue: '1',
      documentFiles: ['AAA', 'BBB'],
      documentPurpose: 'DOCUMENT_PURPOSE_ONBOARDING',
    },
    callbackUri,
  );

  assert.deepEqual(body.document, {
    purpose: 'DOCUMENT_PURPOSE_ONBOARDING',
    files: [{ data: 'AAA' }, { data: 'BBB' }],
  });
});

test('leaves the document out when no file was chosen', () => {
  const body = buildProcessBody(
    flow('idunicodocs_r2'),
    { duiType: 'DUI_TYPE_BR_CPF', duiValue: '1', documentFiles: [], documentPurpose: 'DOCUMENT_PURPOSE_ONBOARDING' },
    callbackUri,
  );

  assert.equal(body.document, undefined);
});

test('ignores extra fields the flow does not take', () => {
  const body = buildProcessBody(
    flow('idlive_r2'),
    {
      duiType: 'DUI_TYPE_BR_CPF',
      duiValue: '1',
      documentFiles: ['AAA'],
      useCase: 'USE_CASE_LOGIN',
      referenceProcessId: 'p',
    },
    callbackUri,
  );

  assert.deepEqual(Object.keys(body), ['flow', 'callbackUri', 'person']);
});

test('adds useCase and a process reference on Smart Revalidation flows', () => {
  const body = buildProcessBody(
    flow('idsmart_r2'),
    { duiType: 'DUI_TYPE_BR_CPF', duiValue: '1', useCase: 'USE_CASE_LOGIN', referenceProcessId: 'abc-123' },
    callbackUri,
  );

  assert.equal(body.useCase, 'USE_CASE_LOGIN');
  assert.deepEqual(body.references, [{ referenceType: 'REFERENCE_TYPE_PROCESS_ID', referenceContent: 'abc-123' }]);
});

test('maps the advanced fields to the API shape', () => {
  const body = buildProcessBody(
    flow('idlive_r2'),
    {
      duiType: 'DUI_TYPE_BR_CPF',
      duiValue: '1',
      expiresIn: '3600s',
      purpose: 'creditprocess',
      companyName: 'Acme',
      currency: 'BRL',
      price: '99.90',
      locale: 'ptBr',
      reason: 'Confirm your purchase',
    },
    callbackUri,
  );

  assert.equal(body.expiresIn, '3600s');
  assert.equal(body.purpose, 'creditprocess');
  assert.deepEqual(body.contextualization, {
    company_name: 'Acme',
    currency: 'BRL',
    price: 99.9,
    locale: { ptBr: { reason: 'Confirm your purchase' } },
  });
});
