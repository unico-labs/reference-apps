# AGENTS.md · web

Rules for agents reading or porting the web reference app. The repo-wide rules in [`../AGENTS.md`](../AGENTS.md) apply too. `CLAUDE.md` is a symlink to this file.

## What it is

One Express server with EJS templates. It renders every page, holds the service account, calls Unico and opens the journey in one of two modes, chosen on the form: Direct Access, an HTTP redirect with no client-side JavaScript, or the Journeys SDK, a page that opens the journey as a widget. How to run it is in [`README.md`](README.md#run).

## Where each piece is

| Path | What it does | How to use it |
|---|---|---|
| `api/unico.js` | Unico client: JWT, access token, Create Process, Get Process, selfie, evidence set. Plain objects in and out, `UnicoError` with status and body | Reference for your own client: endpoints, JWT claims, token renewal and error handling |
| `settings/` | Reads `.env`, checks the private key at startup, builds `publicUrl` | Reference for the startup key check; the rest is your config |
| `flows/flows.js` | Builds the Create Process body from form values. The form imports the same file to preview the request | Reference for mapping your data to the Create Process body |
| `views/` | EJS templates: the form (home page; when creation fails, an error screen with the form kept filled behind it), result and error pages | Reference for your own pages |
| `journey/direct-access/` | Answers with `303 See Other` to `userRedirectUrl`. Imports nothing | Reference for opening the journey with Direct Access |
| `journey/journeys-sdk/` | Renders `journey.ejs` with the process id and token. The page imports `unico-journey-sdk` by name, as in the docs; an import map points the name at the ES module the app serves from `node_modules`. Then it calls `init` and `open`. Behind the widget the page shows the journey in progress, and if the widget is closed before the end, offers a new test. In UAT, calling `open` again on the same process after a `CLOSE` didn't reopen the widget; the [SDK docs](https://developer.unico.io/developers/sdks-and-tools/web) don't cover reopening | Reference for opening the journey with the Journeys SDK widget |
| `result/` | Keeps the process id in a cookie across the journey, then renders the process JSON and selfie, and serves the evidence set PDF | Reference for the calls after the callback; correlate with your own identifier, not a cookie (see below) |
| `app.js` | Routes, form parsing, the origin check, the body size limit and loading each folder in `journey/` as a mode | Reference for the guards; the routing is your framework's |
| `public/style.css`, `server.js` | Styles, entry point | Demo only |

## The flow, end to end

1. `GET /` renders the form. The flow is typed by name: the app doesn't know which flows the account has, so a wrong or disabled one fails on creation and the page shows the API's answer, raw, with the form still filled in behind it. `GET /?references={id}` prefills a step-up on that process.
2. `POST /process`: `app.js` builds the body with `callbackUri` set to `{PUBLIC_URL}/result` and calls `createProcess`, the same for every mode. `result/` sets the `unico_process_id` cookie, and the mode named in the form's `journey` field opens the journey:
   - `journey/direct-access/` answers `303` to `process.userRedirectUrl`.
   - `journey/journeys-sdk/` renders the journey page, which calls `ByUnicoSDK.init({ token, env })` and `ByUnicoSDK.open({ transactionId, token, onFinish })` with `process.id` and `process.token`.
3. When the journey ends, Direct Access returns through Unico's redirect to `callbackUri`, and the Journeys SDK through `onFinish`, which navigates to `/result`. The app doesn't rely on anything Unico might add to that URL, which is why the id went into the cookie first.
4. `GET /result` reads the cookie and makes one `GET` for the process and one for the selfie. `GET /result/evidenceset` makes one `GET` for the PDF when the user opens it. This repo's rule: one `GET` after the callback, no polling and no webhook.

## Building your own integration

Treat this app as a reference, not as code to copy file by file. Read how each piece works, then write it the way your codebase and framework do things.

- `api/unico.js` and `flows/flows.js` have no framework code, so they are the clearest place to see each call, its full docs path and the body it sends. Follow the docs pages linked next to each call.
- Each journey mode is one folder. Read only the mode you use; one mode never imports another. CI deletes one mode at a time and runs the tests, so each mode works alone.
- Direct Access: the redirect answers the form post, so the browser leaves in the same tab.
- Journeys SDK: install `unico-journey-sdk` in your frontend and import it as your bundler does; this app serves its ES module build only because it has no bundler. Only `process.id` and `process.token` go to the page. `onFinish` fires with `type: 'FINISH'` when the journey ends, then make the one `GET` for the process; with `'CLOSE'` the user closed the widget before finishing, so let them start again. Pass `env: 'uat'` only for the test environment. The SDK only opens on domains registered in your account's console panel, per environment and over HTTPS. On any other domain the widget doesn't open, nothing throws and no callback fires: the only sign is `Domain not allowed` in the browser console, so a `try/catch` won't catch it. Close DevTools before the capture: open DevTools count as a fraud signal and block the submission. Never run it inside a WebView, and don't build the old full-screen modal: the journey shows as the CBU 3.0 widget.
- Correlate the return with your own identifier. This app keeps the process id in a cookie only because it has no database. In your app, create your own id first (an order, an onboarding record), put it in the `callbackUri` path, such as `https://your-app.example.com/onboarding/{yourId}/callback`, and store it with `process.id` once the process is created. On the callback, look up `process.id` by that id and make the one `GET`. Prefer the path to a query string: the docs don't say whether Unico keeps the query when it redirects back. Check that the id belongs to the signed-in user, since anyone holding the link can open it.
- If you do use a cookie, keep it `HttpOnly` and `SameSite=Lax`. Unico's redirect back is a cross-site navigation, and `Strict` cookies wouldn't be sent.
- Set `PUBLIC_URL` (or your framework's equivalent) to the address users actually see, since the `callbackUri` is built from it. Building it from the request's `Host` header lets anyone who controls that header choose where users land after the journey.
- Keep the guards in `app.js` in your own routes: refuse form posts from other origins, since the server acts with the service account, and cap the request body size.
- Escape everything you render that came from Unico or the user. The templates use `<%= %>`, which escapes; `<%-` is only for `include`.
