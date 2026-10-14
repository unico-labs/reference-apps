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

const startWithKey = (name, contents) => {
  const path = join(dir, name);
  writeFileSync(path, contents);
  return spawnSync(process.execPath, ['src/server.js'], {
    env: { ...process.env, UNICO_SERVICE_ACCOUNT: 'my-account@abc123.iam.acesso.io', UNICO_PRIVATE_KEY_PATH: path },
    encoding: 'utf8',
    timeout: 5000,
  });
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
