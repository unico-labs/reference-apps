# AGENTS.md

Rules for coding agents (Claude Code, Codex, Cursor, Copilot and others) that read or port code from this repository. `CLAUDE.md` is a symlink to this file.

## What this repo is

Reference apps for integrating with the **Unico API**, the primary, recommended path. There is one app per stack (web, Android, iOS, Flutter), and they all share the same folder layout.

The documentation is the source of truth. Start at https://developer.unico.io/llms.txt. If an app and the docs disagree, the app is wrong and gets fixed. If the docs are wrong, the docs get fixed first.

## Layout

```text
web/       Express server: renders the EJS pages, holds the service account, redirects to the journey
android/   Jetpack Compose
ios/       SwiftUI
flutter/   Flutter
```

Inside each app:

| Folder | Contents |
|---|---|
| `settings/` | Environment (UAT/PROD) and credentials. On web, the server's `.env`. On mobile, demo-mode credentials |
| `flows/` | The create-process form: the flow typed by name, the person and the extra fields. On iOS, still the Sign-up × Step-up menu with its copy of `flows.json` |
| `journey/direct-access/` | Web only: same-tab redirect to the journey link |
| `journey/journeys-sdk/` | Web only: `unico-journey-sdk` with the widget |
| `journey/native-sdk/` | Mobile only: Unico's native SDK, opened with the `webAppToken` |
| `result/` | Raw JSON from `GET /process/{id}`, the selfie and the evidence set |
| `api/` | Calls to Unico. On web, made by the server. On mobile, made from the device in demo mode |

Each journey mode under `journey/` is self-contained. Use the apps as a reference, not as code to copy: read the mode you need in its folder alone and write it your own way.

## Picking a flow

Pick by use case (sign-up or step-up) and region (Global, Brazil, Mexico). [`flows.json`](flows.json) mirrors the [Flows](https://developer.unico.io/developers/start/flows) page in the docs, with each flow's region, group, capabilities and extra form fields. Each app embeds an identical copy, and CI fails if a copy drifts from the root file.

## Hard rules

- Production credentials live only on a server. In production, use one and never store the key on the device or in the browser.
- Don't copy code marked as demo.
- After the callback, make a single `GET` for the process. No polling, no webhook.
- Never run the Journeys SDK inside a WebView.
- On mobile, open the journey with the native SDK. Never in a WebView, Custom Tabs or the system browser.
- The client always creates the process.
- Show the API response as it came back, without interpreting it. A screen may name the value the API returned in words (`PROCESS_RESULT_OK` as "Success") and say what to check next, but the raw response stays on screen next to it.
- Never commit credentials, `.pem` keys or `.env` files.
