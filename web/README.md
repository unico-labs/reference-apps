# Web (Node + Express, server-rendered)

One Express server that renders the pages from EJS templates in [`views/`](views/), holds the Unico service account and opens the journey with Direct Access: it answers the form with a redirect to the journey, and Unico sends the user back to its `/result` page, which shows the process JSON, the selfie and the evidence set PDF as returned.

> **The service account key lives on the server.** Never ship it in a web page or an app: anything sent to a browser or a device is public.

## Run

Requires Node 24 (LTS) and a service account. See the root [README](../README.md#credentials) for how to get one.

```sh
npm install
cp .env.example .env
```

Fill in `.env` with your service account. The server exits with a message if a value is missing or the key file isn't a PEM private key. Keep the `.pem` file exactly as you received it: a key pasted onto one line, or with literal `\n` in it, won't load.

```sh
npm start
```

Open http://localhost:3000, pick a flow and fill in the form with your own document.

## Test

The tests run against a local fake of the Unico endpoints and need no credentials.

```sh
npm install
npm test
npm run lint    # Biome: smells and formatting, same check as CI
```

`npm run format` applies the fixable lint and formatting changes. It rewrites files.

## Using `api/unico.js` as a reference

[`api/unico.js`](api/unico.js) shows every Unico call this app makes. Use it as a reference for your own client, not as a file to copy. It has no framework code and only needs `jsonwebtoken`. It signs the JWT as in the [Authentication](https://developer.unico.io/developers/start/authentication) example, caches the access token and renews it when 10 minutes or less remain.

```js
import { readFileSync } from 'node:fs';
import { createUnico, HOSTS, UnicoError } from './api/unico.js';

const unico = createUnico({
  serviceAccount: 'my-account@abc123.iam.acesso.io',
  privateKey: readFileSync('/secure/path/private-key.pem'),
  hosts: HOSTS.uat,
});

try {
  const { process } = await unico.createProcess({
    flow: 'idlive_r2',
    callbackUri: 'https://your-app.example.com/onboarding/order-123/callback',
    person: { duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909' },
  });
  // process is { id, userRedirectUrl, token, ... }: store process.id with order-123, then redirect to process.userRedirectUrl.
} catch (err) {
  if (err instanceof UnicoError) console.error(err.status, err.body);
  else throw err;
}
```

`getProcess(id)` returns `{ process: { id, state, result, ... } }`. `getSelfie(id)` and `getEvidenceSet(id)` return `{ fileContents, contentType }`, with the file in base64. Every non-2xx answer from Unico throws a `UnicoError` with the status and body as returned. A malformed process id throws an `InvalidInputError` before anything is sent.

## Code

[`AGENTS.md`](AGENTS.md) explains where each piece is, how the redirect and callback work, and how to port the app to another framework.
