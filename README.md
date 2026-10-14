# Unico API · Reference apps

Official reference apps for integrating with the [Unico API](https://developer.unico.io). Each stack shows how to create a process, open the journey and read the result, always with the same folder layout.

Using a coding agent? Point it at [`AGENTS.md`](AGENTS.md).

## Stacks

| Stack | Folder | Journey mode | Status |
|---|---|---|---|
| Node backend | [`backend/`](backend/) | n/a | Planned |
| Web (vanilla JS) | [`web/`](web/) | Direct Access, Journeys SDK | Planned |
| Android (Jetpack Compose) | [`android/`](android/) | Direct Access (WebView) | Planned |
| iOS (SwiftUI) | [`ios/`](ios/) | Direct Access (WKWebView) | Planned |
| Flutter | [`flutter/`](flutter/) | Direct Access (WebView) | Planned |

Native SDK (SDK-S) support on mobile comes in a later phase.

## Credentials

To run the apps you need a Unico service account: account, tenant and `.pem` key. UAT and PROD each have their own.

Ask your Unico sales contact or the Unico Onboarding team for one. See [Authentication](https://developer.unico.io/developers/start/authentication) for how it works and [Environments](https://developer.unico.io/developers/start/environments) for the hosts of each environment.

Never commit the key. In production it lives only on the backend.

## License

[MIT](LICENSE)
