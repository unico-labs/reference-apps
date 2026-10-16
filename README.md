# Unico API · Reference apps

Official reference apps for integrating with the [Unico API](https://developer.unico.io). Each stack shows how to create a process, open the journey and read the result, always with the same folder layout.

Using a coding agent? Point it at [`AGENTS.md`](AGENTS.md).

## Stacks

| Stack | Folder | Journey mode | Status |
|---|---|---|---|
| Web (Node + Express, server-rendered) | [`web/`](web/) | Direct Access, Journeys SDK | Direct Access available |
| Android (Jetpack Compose) | [`android/`](android/) | Native SDK | Native SDK available |
| iOS (SwiftUI) | [`ios/`](ios/) | Native SDK | Native SDK available |
| Flutter | [`flutter/`](flutter/) | Native SDK | Planned |

## Credentials

To run the apps you need a Unico service account: account, tenant and `.pem` key. UAT and PROD each have their own.

Ask your Unico sales contact or the Unico Onboarding team for one. See [Authentication](https://developer.unico.io/developers/start/authentication) for how it works and [Environments](https://developer.unico.io/developers/start/environments) for the hosts of each environment.

Never commit the key. In production it lives only on your server.

## License

[MIT](LICENSE)
