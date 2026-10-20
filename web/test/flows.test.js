import assert from 'node:assert/strict';
import { test } from 'node:test';
import { buildProcessBody } from '../flows/flows.js';

const callbackUri = 'http://localhost:3000/result';
const person = { flow: 'idlive_r2', duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909' };

test('sends the typed flow and only the fields that were filled in', () => {
  const body = buildProcessBody({ ...person, flow: ' idlive_r2 ', friendlyName: '', expiresIn: '' }, callbackUri);

  assert.deepEqual(body, {
    flow: 'idlive_r2',
    callbackUri,
    person: { duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909' },
  });
});

test('adds the document files when the document is turned on', () => {
  const body = buildProcessBody({ ...person, withDocument: 'on', documentFiles: ['AAA', 'BBB'] }, callbackUri);

  assert.deepEqual(body.document, { files: [{ data: 'AAA' }, { data: 'BBB' }] });
});

test('adds the document purpose when the document is turned on', () => {
  const body = buildProcessBody(
    { ...person, withDocument: 'on', documentFiles: ['AAA'], documentPurpose: 'DOCUMENT_PURPOSE_ONBOARDING' },
    callbackUri,
  );

  assert.deepEqual(body.document, { purpose: 'DOCUMENT_PURPOSE_ONBOARDING', files: [{ data: 'AAA' }] });
});

test('leaves the document out when it is turned off or has no file', () => {
  assert.equal(buildProcessBody({ ...person, documentFiles: ['AAA'] }, callbackUri).document, undefined);
  assert.equal(buildProcessBody({ ...person, withDocument: 'on', documentFiles: [] }, callbackUri).document, undefined);
});

test('adds useCase and a process reference when they are turned on', () => {
  const body = buildProcessBody(
    { ...person, withReferences: 'on', useCase: 'USE_CASE_LOGIN', referenceProcessId: 'abc-123' },
    callbackUri,
  );

  assert.equal(body.useCase, 'USE_CASE_LOGIN');
  assert.deepEqual(body.references, [{ referenceType: 'REFERENCE_TYPE_PROCESS_ID', referenceContent: 'abc-123' }]);
});

test('leaves useCase and references out when they are turned off', () => {
  const body = buildProcessBody({ ...person, useCase: 'USE_CASE_LOGIN', referenceProcessId: 'abc-123' }, callbackUri);

  assert.deepEqual(Object.keys(body), ['flow', 'callbackUri', 'person']);
});

test('maps the name, expiresIn and purpose to the API shape', () => {
  const body = buildProcessBody(
    { ...person, friendlyName: 'Ana', expiresIn: '3600s', purpose: 'creditprocess' },
    callbackUri,
  );

  assert.equal(body.person.friendlyName, 'Ana');
  assert.equal(body.expiresIn, '3600s');
  assert.equal(body.purpose, 'creditprocess');
});

test('leaves the person out when no document number was typed', () => {
  const body = buildProcessBody({ flow: 'idlive_r2', duiType: 'DUI_TYPE_BR_CPF', duiValue: '' }, callbackUri);

  assert.deepEqual(body, { flow: 'idlive_r2', callbackUri });
});

test('maps the email and phone to the person', () => {
  const body = buildProcessBody({ ...person, email: 'ana@example.com', phone: '5511999999999' }, callbackUri);

  assert.equal(body.person.email, 'ana@example.com');
  assert.equal(body.person.phone, '5511999999999');
});

test('maps the contextualization to the API shape when it is turned on', () => {
  const body = buildProcessBody(
    {
      ...person,
      withContextualization: 'on',
      companyName: 'Acme',
      currency: 'BRL',
      price: '99.90',
      locale: 'ptBr',
      reason: 'Confirm your purchase',
    },
    callbackUri,
  );

  assert.deepEqual(body.contextualization, {
    company_name: 'Acme',
    currency: 'BRL',
    price: 99.9,
    locale: { ptBr: { reason: 'Confirm your purchase' } },
  });
});

test('leaves the contextualization out when it is turned off', () => {
  const body = buildProcessBody({ ...person, companyName: 'Acme', currency: 'BRL' }, callbackUri);

  assert.equal(body.contextualization, undefined);
});
