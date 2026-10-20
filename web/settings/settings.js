// Server settings, read from environment variables (see .env.example). The service account key stays here,
// on the server: the browser only gets HTML, a redirect, or the process id and token for the Journeys SDK.
import { createPrivateKey } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { HOSTS } from '../api/unico.js';

function fail(message) {
  console.error(message);
  process.exit(1);
}

// A key copied from an email or a JSON payload often loses its line breaks. jsonwebtoken would only
// fail on the first request, with "must be an asymmetric key", so check the key at startup instead.
function loadPrivateKey(path) {
  let pem;
  try {
    pem = readFileSync(path, 'utf8');
  } catch {
    fail(`UNICO_PRIVATE_KEY_PATH: cannot read ${path}`);
  }
  try {
    return createPrivateKey(pem);
  } catch {
    const header = pem.match(/-----BEGIN ([A-Z ]+)-----/)?.[1];
    fail(
      `UNICO_PRIVATE_KEY_PATH is not a PEM private key (${header ? `found: ${header}` : 'no PEM header'}). ` +
        'It should start with -----BEGIN PRIVATE KEY----- and keep its original line breaks.',
    );
  }
}

export function loadSettings(env) {
  const { UNICO_ENV = 'uat', UNICO_SERVICE_ACCOUNT, UNICO_PRIVATE_KEY_PATH, PORT = '3000' } = env;
  if (!Object.hasOwn(HOSTS, UNICO_ENV) || !UNICO_SERVICE_ACCOUNT || !UNICO_PRIVATE_KEY_PATH) {
    fail('Set UNICO_ENV (uat or prod), UNICO_SERVICE_ACCOUNT and UNICO_PRIVATE_KEY_PATH. See .env.example.');
  }
  // The JWT's iss, from https://developer.unico.io/developers/start/authentication. The docs hand out the account
  // name and the tenant ID separately, so a value with only one of them is a common mistake.
  if (!/^[^@]+@[^.@]+\.iam\.acesso\.io$/.test(UNICO_SERVICE_ACCOUNT)) {
    fail(
      `UNICO_SERVICE_ACCOUNT must look like <account_name>@<tenant_id>.iam.acesso.io (got: ${UNICO_SERVICE_ACCOUNT}).`,
    );
  }

  // Where browsers reach this app. It builds the callbackUri, so it must be the address users actually see.
  const publicUrl = (env.PUBLIC_URL ?? `http://localhost:${PORT}`).replace(/\/+$/, '');
  if (!['http:', 'https:'].includes(URL.parse(publicUrl)?.protocol)) {
    fail(`PUBLIC_URL must be an http or https address, such as https://your-app.example.com (got: ${publicUrl}).`);
  }

  return {
    env: UNICO_ENV,
    hosts: HOSTS[UNICO_ENV],
    serviceAccount: UNICO_SERVICE_ACCOUNT,
    privateKey: loadPrivateKey(UNICO_PRIVATE_KEY_PATH),
    port: Number(PORT),
    publicUrl,
  };
}
