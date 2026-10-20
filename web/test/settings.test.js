import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { generateKeyPairSync } from 'node:crypto';
import { mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { after, test } from 'node:test';

const dir = mkdtempSync(join(tmpdir(), 'unico-keys-'));
after(() => rmSync(dir, { recursive: true }));

const { privateKey, publicKey } = generateKeyPairSync('rsa', {
  modulusLength: 2048,
  privateKeyEncoding: { type: 'pkcs8', format: 'pem' },
  publicKeyEncoding: { type: 'spki', format: 'pem' },
});

const start = (env) =>
  spawnSync(process.execPath, ['server.js'], {
    env: { ...process.env, UNICO_SERVICE_ACCOUNT: 'my-account@abc123.iam.acesso.io', ...env },
    encoding: 'utf8',
    timeout: 5000,
  });

const startWithKey = (name, contents, env = {}) => {
  const path = join(dir, name);
  writeFileSync(path, contents);
  return start({ UNICO_PRIVATE_KEY_PATH: path, ...env });
};

test('refuses to start with a key that lost its line breaks', () => {
  const { status, stderr } = startWithKey('one-line.pem', privateKey.replaceAll('\n', '\\n'));

  assert.equal(status, 1);
  assert.match(stderr, /is not a PEM private key/);
  assert.match(stderr, /line breaks/);
});

test('refuses to start with a public key and names what it found', () => {
  const { status, stderr } = startWithKey('public.pem', publicKey);

  assert.equal(status, 1);
  assert.match(stderr, /found: PUBLIC KEY/);
});

test('refuses to start when the key file is missing and names the path', () => {
  const path = join(dir, 'missing.pem');
  const { status, stderr } = start({ UNICO_PRIVATE_KEY_PATH: path });

  assert.equal(status, 1);
  assert.match(stderr, new RegExp(`UNICO_PRIVATE_KEY_PATH: cannot read ${path}`));
  assert.doesNotMatch(stderr, /ENOENT/);
});

test('refuses to start with a UNICO_ENV that is not uat or prod', () => {
  const { status, stderr } = startWithKey('env.pem', privateKey, { UNICO_ENV: 'constructor' });

  assert.equal(status, 1);
  assert.match(stderr, /Set UNICO_ENV \(uat or prod\)/);
});

for (const url of ['localhost:3000', 'ftp://example.com', 'not a url']) {
  test(`refuses to start with PUBLIC_URL=${url}`, () => {
    const { status, stderr } = startWithKey('url.pem', privateKey, { PUBLIC_URL: url });

    assert.equal(status, 1);
    assert.match(stderr, /PUBLIC_URL/);
  });
}
