// The first screen on a device with no settings: what the app does and what setup asks for.
import SwiftUI

struct WelcomeScreen: View {
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Label {
                    Text("Unico reference app").font(.subheadline.bold()).foregroundStyle(Color.ink)
                } icon: {
                    Image(systemName: "checkmark.square.fill").foregroundStyle(Color.accent)
                }
                Text("See how a Unico integration works").font(.largeTitle.weight(.heavy)).foregroundStyle(Color.ink)
                Text("Run a real flow in UAT. You see the request a backend would send and the result that comes back.")
                    .foregroundStyle(Color.muted)
            }

            VStack(alignment: .leading, spacing: 12) {
                Lab("How it works")
                step(1, "Set up this app", "Add your API credentials and SDK settings once.")
                step(2, "Run a flow", "Type the flow name and the person's document.")
                step(3, "Read the result", "See the response, the selfie and the evidence set.")
            }

            VStack(alignment: .leading, spacing: 12) {
                Lab("What you'll need")
                Card {
                    need("API credentials",
                         "Service account, Tenant ID and private key. They let this app create the process when you start a test.",
                         "In your own app this runs on your backend.")
                    DocLink(title: "Authentication guide ↗", url: "https://developer.unico.io/developers/start/authentication")
                }
                Card {
                    need("SDK settings", "SDK key and app ID. They let the camera experience open.",
                         "Unico issues the SDK key for your app's bundle ID.")
                    DocLink(title: "iOS setup ↗", url: "https://developer.unico.io/developers/sdks-and-tools/ios/initialization")
                }
            }
        }
        .screen {
            Button("Get started", action: onStart).buttonStyle(PrimaryButtonStyle())
        }
    }

    private func step(_ number: Int, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)").font(.caption.monospaced().bold()).foregroundStyle(Color.accent)
                .frame(width: 26, height: 26).background(Color.extraGround, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold()).foregroundStyle(Color.ink)
                Hint(text)
            }
        }
    }

    private func need(_ title: String, _ text: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.subheadline.bold()).foregroundStyle(Color.ink)
            Text(text).font(.footnote).foregroundStyle(Color.ink)
            Hint(note)
        }
    }
}
