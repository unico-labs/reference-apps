import { createPrivateKey } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { createUnico, HOSTS, InvalidInputError } from './unico.js';

const {
  UNICO_ENV = 'uat',
  UNICO_SERVICE_ACCOUNT,
  UNICO_PRIVATE_KEY_PATH,
  ALLOWED_ORIGIN = 'http://localhost:8080',
  PORT = '3000',
} = process.env;

if (!HOSTS[UNICO_ENV] || !UNICO_SERVICE_ACCOUNT || !UNICO_PRIVATE_KEY_PATH) {
  console.error('Set UNICO_ENV (uat or prod), UNICO_SERVICE_ACCOUNT and UNICO_PRIVATE_KEY_PATH. See .env.example.');
  process.exit(1);
}

// A key copied from an email or a JSON payload often loses its line breaks. jsonwebtoken would only
// fail on the first request, with "must be an asymmetric key", so check the key here instead.
function loadPrivateKey(path) {
  const pem = readFileSync(path, 'utf8');
  try {
    return createPrivateKey(pem);
  } catch {
    const header = pem.match(/-----BEGIN ([A-Z ]+)-----/)?.[1];
    console.error(
      `UNICO_PRIVATE_KEY_PATH is not a PEM private key (${header ? `found: ${header}` : 'no PEM header'}). ` +
        'It should start with -----BEGIN PRIVATE KEY----- and keep its original line breaks.',
    );
    process.exit(1);
  }
}

const unico = createUnico({
  serviceAccount: UNICO_SERVICE_ACCOUNT,
  privateKey: loadPrivateKey(UNICO_PRIVATE_KEY_PATH),
  hosts: HOSTS[UNICO_ENV],
});

// Create Process carries base64 documents and reference images. The docs don't set a request size limit,
// so 15 MB is a judgment call with room for a few document files. Lower it if your flows send no documents.
const MAX_BODY_BYTES = 15 * 1024 * 1024;

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
    this.body = { error: message };
  }
}

async function readJsonBody(req) {
  const chunks = [];
  let size = 0;
  for await (const chunk of req) {
    size += chunk.length;
    if (size > MAX_BODY_BYTES) throw new HttpError(413, 'body too large');
    chunks.push(chunk);
  }
  try {
    return JSON.parse(Buffer.concat(chunks).toString());
  } catch {
    throw new HttpError(400, 'body is not valid JSON');
  }
}

async function route(req) {
  const { pathname } = new URL(req.url, 'http://localhost');

  if (req.method === 'POST' && pathname === '/process') return unico.createProcess(await readJsonBody(req));

  const match = req.method === 'GET' && pathname.match(/^\/process\/([^/]+)(?:\/(selfie|evidenceset))?$/);
  if (match) {
    const [, id, resource] = match;
    if (resource === 'selfie') return unico.getSelfie(id);
    if (resource === 'evidenceset') return unico.getEvidenceSet(id);
    return unico.getProcess(id);
  }

  throw new HttpError(404, 'not found');
}

createServer(async (req, res) => {
  // Only the web app's origin may call this backend, since it acts with the service account.
  res.setHeader('Access-Control-Allow-Origin', ALLOWED_ORIGIN);
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.writeHead(204).end();

  // UnicoError and HttpError both carry status and body, so the web app sees Unico's errors as they came back.
  let status = 200;
  let body;
  try {
    body = await route(req);
  } catch (err) {
    status = err.status ?? (err instanceof InvalidInputError ? 400 : 502);
    body = err.body ?? { error: err.message };
  }

  // A non-JSON answer (a gateway's HTML error page, for example) goes back as text, not re-encoded.
  if (typeof body === 'string') return res.writeHead(status, { 'Content-Type': 'text/plain' }).end(body);
  res.writeHead(status, { 'Content-Type': 'application/json' }).end(JSON.stringify(body));
}).listen(Number(PORT), () => console.log(`Backend listening on http://localhost:${PORT} (${UNICO_ENV})`));
