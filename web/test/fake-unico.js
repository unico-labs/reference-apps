import { generateKeyPairSync } from 'node:crypto';
import { readdirSync } from 'node:fs';
import { createServer } from 'node:http';
import { createUnico } from '../api/unico.js';
import { createApp } from '../app.js';

const { privateKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  publicKeyEncoding: { type: 'spki', format: 'pem' },
});

export const pdf = Buffer.from('%PDF-1.3\n%%EOF\n');

// Whichever journey modes are left in journey/, so the shared tests pass with any one of them removed.
export const journeys = readdirSync(new URL('../journey/', import.meta.url), { withFileTypes: true })
  .filter((entry) => entry.isDirectory())
  .map((entry) => entry.name);

// Starts the app against a local fake of the Unico endpoints. `created` collects every Create Process body.
export async function startApp() {
  const created = [];
  const routes = {
    'POST /oauth2/token': () => [200, { access_token: 'token', token_type: 'Bearer', expires_in: 3600 }],
    'POST /client/v1/process': (body) => {
      created.push(body);
      if (body.flow === 'not_a_flow') return [400, { code: 3, message: '<script>alert(1)</script>' }];
      const userRedirectUrl =
        body.flow === 'idtrust_r2'
          ? 'https://cadastro.uat.unico.app/flow?id=abc-123&q=%zz|'
          : 'https://cadastro.uat.unico.app/abc';
      return [200, { process: { id: 'abc-123', userRedirectUrl, token: 'process-token' } }];
    },
    'GET /client/v1/process/abc-123': () => [
      200,
      {
        process: {
          id: 'abc-123',
          flow: 'idlive_r2',
          state: 'PROCESS_STATE_FINISHED',
          result: 'PROCESS_RESULT_OK',
          createdAt: '2026-10-19T12:00:00Z',
          finishedAt: '2026-10-19T12:00:38Z',
        },
      },
    ],
    'GET /client/v1/process/def-456': () => [
      200,
      { process: { id: 'def-456', state: 'PROCESS_STATE_FINISHED', result: 'PROCESS_RESULT_INVALID_IDENTITY' } },
    ],
    'GET /client/v1/process/abc-123/selfie': () => [200, { fileContents: '/9j/4AAQ', contentType: 'image/jpeg' }],
    'GET /client/v1/process/abc-123/evidenceset': () => [
      200,
      { fileContents: pdf.toString('base64'), contentType: 'x-pdf' },
    ],
  };

  const fakeUnico = createServer(async (req, res) => {
    let body = '';
    for await (const chunk of req) body += chunk;
    const result = req.url.match(/^\/client\/v1\/process\/(PROCESS_RESULT_\w+)$/)?.[1];
    const route = result
      ? () => [200, { process: { id: result, state: 'PROCESS_STATE_FINISHED', result } }]
      : routes[`${req.method} ${req.url}`];
    const [status, payload] = route
      ? route(body && req.headers['content-type'] === 'application/json' ? JSON.parse(body) : body)
      : [404, { code: 5, message: 'error getting process: rpc error: code = NotFound desc = process not found' }];
    res.writeHead(status, { 'Content-Type': 'application/json' }).end(JSON.stringify(payload));
  });
  await new Promise((resolve) => fakeUnico.listen(0, resolve));
  const fakeUrl = `http://localhost:${fakeUnico.address().port}`;

  let handler;
  const server = createServer((req, res) => handler(req, res));
  await new Promise((resolve) => server.listen(0, resolve));
  const publicUrl = `http://localhost:${server.address().port}`;

  const serviceAccount = 'my-account@abc123.iam.acesso.io';
  const unico = createUnico({
    serviceAccount,
    privateKey,
    hosts: { identity: fakeUrl, api: fakeUrl },
  });
  handler = createApp({ unico, publicUrl, env: 'uat', serviceAccount });

  return {
    publicUrl,
    created,
    get: (path, headers = {}) => fetch(`${publicUrl}${path}`, { headers, redirect: 'manual' }),
    post: (path, body, headers = {}) =>
      fetch(`${publicUrl}${path}`, {
        method: 'POST',
        body,
        headers: { Origin: publicUrl, ...headers },
        redirect: 'manual',
      }),
    close: () => {
      server.close();
      fakeUnico.close();
    },
  };
}
