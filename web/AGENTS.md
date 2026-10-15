# AGENTS.md · web

Rules for agents reading or porting the web reference app. The repo-wide rules in [`../AGENTS.md`](../AGENTS.md) apply too. `CLAUDE.md` is a symlink to this file.

## What it is

One Express server with EJS templates and no client-side JavaScript. It renders every page, holds the service account, calls Unico and opens the journey by HTTP redirect. How to run it is in [`README.md`](README.md#run).

## Where each piece is

| Path | What it does | How to use it |
|---|---|---|
| `api/unico.js` | Unico client: JWT, access token, Create Process, Get Process, selfie, evidence set. Plain objects in and out, `UnicoError` with status and body | Reference for your own client: endpoints, JWT claims, token renewal and error handling |
| `settings/` | Reads `.env`, checks the private key at startup, builds `publicUrl` | Reference for the startup key check; the rest is your config |
| `flows/flows.js` | Filters flows and builds the Create Process body from form values | Reference for mapping your data to the Create Process body |
| `flows/flows.json` | Copy of the root `flows.json`. CI fails if it drifts | Reference for which flows exist and the fields each one needs |
| `views/` | EJS templates: menu, form, result and error pages | Reference for your own pages |
| `journey/direct-access/` | Answers with `303 See Other` to `userRedirectUrl`. Imports nothing | Reference for opening the journey with Direct Access |
| `result/` | Keeps the process id in a cookie across the journey, then renders the process JSON and selfie, and serves the evidence set PDF | Reference for the calls after the callback; correlate with your own identifier, not a cookie (see below) |
| `app.js` | Routes, form parsing, the origin check and the body size limit | Reference for the guards; the routing is your framework's |
| `public/style.css`, `server.js` | Styles, entry point | Demo only |

## The flow, end to end

1. `GET /flows/{id}` renders the form. The browser posts it back to the same URL.
2. `POST /flows/{id}`: `app.js` builds the body with `callbackUri` set to `{PUBLIC_URL}/result` and calls `createProcess`. `result/` sets the `unico_process_id` cookie and `journey/direct-access/` answers `303` to `process.userRedirectUrl`.
3. When the journey ends, Unico redirects the browser to `callbackUri`. The app doesn't rely on anything Unico might add to that URL, which is why the id went into the cookie first.
4. `GET /result` reads the cookie and makes one `GET` for the process and one for the selfie. `GET /result/evidenceset` makes one `GET` for the PDF when the user opens it. This repo's rule: one `GET` after the callback, no polling and no webhook.

## Building your own integration

Treat this app as a reference, not as code to copy file by file. Read how each piece works, then write it the way your codebase and framework do things.

- `api/unico.js` and `flows/flows.js` have no framework code, so they are the clearest place to see each call, its full docs path and the body it sends. Follow the docs pages linked next to each call.
- Each journey mode is one folder. Read only the mode you use; one mode never imports another.
- The redirect answers the form post, so the browser leaves in the same tab. The docs also allow opening the journey in a new tab with `window.open`; that needs client-side code, which this app doesn't have.
- Correlate the return with your own identifier. This app keeps the process id in a cookie only because it has no database. In your app, create your own id first (an order, an onboarding record), put it in the `callbackUri` path, such as `https://your-app.example.com/onboarding/{yourId}/callback`, and store it with `process.id` once the process is created. On the callback, look up `process.id` by that id and make the one `GET`. Prefer the path to a query string: the docs don't say whether Unico keeps the query when it redirects back. Check that the id belongs to the signed-in user, since anyone holding the link can open it.
- If you do use a cookie, keep it `HttpOnly` and `SameSite=Lax`. Unico's redirect back is a cross-site navigation, and `Strict` cookies wouldn't be sent.
- Set `PUBLIC_URL` (or your framework's equivalent) to the address users actually see, since the `callbackUri` is built from it. Building it from the request's `Host` header lets anyone who controls that header choose where users land after the journey.
- Keep the guards in `app.js` in your own routes: refuse form posts from other origins, since the server acts with the service account, and cap the request body size.
- Escape everything you render that came from Unico or the user. The templates use `<%= %>`, which escapes; `<%-` is only for `include`.
