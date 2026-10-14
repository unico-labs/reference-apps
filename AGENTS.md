# AGENTS.md

Rules for coding agents (Claude Code, Codex, Cursor, Copilot and others) that read or port code from this repository. `CLAUDE.md` is a symlink to this file.

## What this repo is

Reference apps for integrating with the **Unico API**, the primary, recommended path. There is one app per stack (web, Android, iOS, Flutter) plus a Node backend, and they all share the same folder layout.

The documentation is the source of truth. Start at https://developer.unico.io/llms.txt. If an app and the docs disagree, the app is wrong and gets fixed. If the docs are wrong, the docs get fixed first.

## Layout

```text
backend/   Node: token, create process, get process, selfie and evidence set
web/       vanilla JS, talks to the backend
android/   Jetpack Compose
ios/       SwiftUI
flutter/   Flutter
```

Inside each app:

| Folder | Contents |
|---|---|
| `settings/` | Environment (UAT/PROD). On web, the backend URL. On mobile, demo-mode credentials |
| `flows/` | Sign-up × Step-up menu, region filter and the create-process form |
| `journey/direct-access/` | Opens the journey from its link: redirect on web, WebView on mobile |
| `journey/journeys-sdk/` | Web only: `unico-journey-sdk` with the widget |
| `journey/sdk-s/` | Mobile only: native SDK (coming later) |
| `result/` | Raw JSON from `GET /process/{id}` and the selfie |
| `api/` | On web, calls to the backend. On mobile, direct calls to Unico in demo mode |

Each journey mode under `journey/` is self-contained. To port a mode, take only that folder and don't mix it with the others.

## Picking a flow

Pick by use case (sign-up or step-up) and region (Global, Brazil, Mexico). [`flows.json`](flows.json) mirrors the [Flows](https://developer.unico.io/developers/start/flows) page in the docs, with each flow's region, group, capabilities and extra form fields. Each app embeds an identical copy, and CI fails if a copy drifts from the root file.

## Hard rules

- Production credentials live only on the backend. In production, use a backend and never store the key on the device.
- Don't copy code marked as demo.
- After the callback, make a single `GET` for the process. No polling, no webhook.
- Never run the Journeys SDK inside a WebView.
- In native apps, the WebView loads only the journey link, with no JS injection and no bridge, and grants only camera access to the Unico origin.
- The client always creates the process.
- Show the API response as it came back, without interpreting it.
- Never commit credentials, `.pem` keys or `.env` files.
