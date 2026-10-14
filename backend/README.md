# Backend (Node)

Holds the Unico service account and calls the Unico API on behalf of the web app. It signs the JWT with [`jsonwebtoken`](https://www.npmjs.com/package/jsonwebtoken), as in the [Authentication](https://developer.unico.io/developers/start/authentication) example, and calls the API with Node's built-in `fetch`.

> **In production, use a backend.** The service account key must live on your server, never in the browser or on the device. A key shipped in a web page or an app is public.

## Run

Requires Node 24 (LTS) and a service account. See the root [README](../README.md#credentials) for how to get one.

```sh
npm install
cp .env.example .env
```

Fill in `.env` with your service account, then start the server. It exits with a message if a value is missing or the key file isn't a PEM private key. Keep the `.pem` file exactly as you received it: a key pasted onto one line, or with literal `\n` in it, won't load.

```sh
npm start
```

## Test

The tests run against a local fake of the Unico endpoints and need no credentials.

```sh
npm install
npm test
npm run lint      # Biome: smells and formatting, same check as CI
npm run format    # apply the fixable ones
```

## Routes

The web app calls these routes. Each one forwards to the Unico API and returns its status and body unchanged, errors included.

| Route | Unico API |
|---|---|
| `POST /process` | [`POST /client/v1/process`](https://developer.unico.io/developers/api-reference/post-processes) |
| `GET /process/{id}` | [`GET /client/v1/process/{id}`](https://developer.unico.io/developers/api-reference/get-process) |
| `GET /process/{id}/selfie` | [`GET /client/v1/process/{id}/selfie`](https://developer.unico.io/developers/api-reference/get-selfie) |
| `GET /process/{id}/evidenceset` | [`GET /client/v1/process/{id}/evidenceset`](https://developer.unico.io/developers/api-reference/get-evidence-set) (evidence set, base64 PDF) |

Creating a process:

```sh
curl -X POST http://localhost:3000/process \
  -H 'Content-Type: application/json' \
  -d '{
    "flow": "idlive_r2",
    "callbackUri": "http://localhost:8080",
    "person": { "duiType": "DUI_TYPE_BR_CPF", "duiValue": "12345678909", "friendlyName": "Maria" }
  }'
```

The answer is `{ "process": { "id": ..., "userRedirectUrl": ..., ... } }`. Open `userRedirectUrl` to run the journey, then call `GET /process/{id}` once after the callback.

## Using `unico.js` in your own backend

[`src/unico.js`](src/unico.js) is the part to copy. It has no framework code and only needs `jsonwebtoken`.

```js
import { readFileSync } from 'node:fs';
import { createUnico, HOSTS, UnicoError } from './unico.js';

const unico = createUnico({
  serviceAccount: 'my-account@abc123.iam.acesso.io',
  privateKey: readFileSync('/secure/path/private-key.pem'),
  hosts: HOSTS.uat,
});

try {
  const { process } = await unico.createProcess({
    flow: 'idlive_r2',
    callbackUri: 'https://your-app.example/callback',
    person: { duiType: 'DUI_TYPE_BR_CPF', duiValue: '12345678909' },
  });
  // Send the user to process.userRedirectUrl.
} catch (err) {
  if (err instanceof UnicoError) console.error(err.status, err.body);
  else throw err;
}
```

`getProcess(id)`, `getSelfie(id)` and `getEvidenceSet(id)` work the same way. Every non-2xx answer from Unico throws a `UnicoError` with the status and body as returned. A malformed process id throws an `InvalidInputError` before anything is sent.

## Where things are

- [`src/unico.js`](src/unico.js): access token and API calls, returning parsed JSON and throwing `UnicoError` on failures. The token is a JWT signed with the service account key (RS256) and exchanged at `POST {identity}/oauth2/token`, as described in [Authentication](https://developer.unico.io/developers/start/authentication). It is cached and renewed when 10 minutes or less remain.
- [`src/server.js`](src/server.js): HTTP routes for the web app, CORS for `ALLOWED_ORIGIN` and configuration from environment variables.
- [`test/`](test/): tests for the API layer against a local fake of the Unico endpoints.
