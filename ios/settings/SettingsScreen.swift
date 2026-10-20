// DEMO ONLY: the Connect screen. In production none of this is on the device; your server holds the credentials.
import SwiftUI

extension Settings {
    var environment: String { hosts == .prod ? "PROD" : "UAT" }
}

// `onVerify` asks Unico for an access token with these settings. It returns an error to show, or nil when the
// token came back; then the verified screen shows, and Continue saves the settings.
struct SettingsScreen: View {
    let initial: Settings
    let onVerify: (Settings) async -> String?
    let onContinue: (Settings) throws -> Void

    @State private var settings: Settings
    // The stored key is never shown again. Leave the field empty to keep it.
    @State private var pem = ""
    @State private var importing = false
    @State private var advanced = false
    @State private var sending = false
    @State private var error: String?
    @State private var verified: Settings?

    init(initial: Settings, onVerify: @escaping (Settings) async -> String?, onContinue: @escaping (Settings) throws -> Void) {
        self.initial = initial
        self.onVerify = onVerify
        self.onContinue = onContinue
        _settings = State(initialValue: initial)
    }

    var body: some View {
        if let verified { connected(verified) } else { form }
    }

    private var form: some View {
        Group {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connect your Unico account").font(.title2.weight(.heavy)).foregroundStyle(Color.ink)
                    Hint("Done once. Used to sign every request.")
                }
                Text("Demo only. Credentials stay on this device; in your own app, keep them on your backend.")
                    .font(.caption.weight(.semibold)).foregroundStyle(Color.warnInk)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color.warnGround, in: RoundedRectangle(cornerRadius: 10))

                Field(label: "Service account", hint: "Your unique account name", text: $settings.account)
                // The JWT iss is built from these two: https://developer.unico.io/developers/start/authentication
                Field(
                    label: "Tenant ID",
                    hint: settings.account.isEmpty || settings.tenant.isEmpty
                        ? "iss: <account_name>@<tenant_id>.iam.acesso.io" : "iss: \(settings.serviceAccount)",
                    text: $settings.tenant
                )

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel(text: "Private key (.pem)")
                    TextField(
                        initial.privateKeyPem.isEmpty ? "-----BEGIN PRIVATE KEY-----" : "Saved. Paste or import to replace it",
                        text: $pem, axis: .vertical
                    )
                    .font(.caption.monospaced())
                    .lineLimit(3...8)
                    .padding(.vertical, 12)
                    .fieldStyle()
                    Hint("Paste it or import the file. Stored in the Keychain.")
                }
                Button("Import .pem file") { importing = true }.buttonStyle(SecondaryButtonStyle())

                // https://developer.unico.io/developers/sdks-and-tools/ios/installation/specific-setup
                Field(label: "SDK key", hint: "Issued by Unico for a Bundle Identifier and Team ID", text: $settings.sdkKey)
                Field(
                    label: "Bundle Identifier",
                    hint: "This build is \(Bundle.main.bundleIdentifier ?? ""). Change it only to try a key issued for another ID",
                    text: $settings.bundleIdentifier
                )

                Button(advanced ? "Hide API endpoints" : "API endpoints (advanced)") { advanced.toggle() }
                    .font(.subheadline.bold()).foregroundStyle(Color.accent)
                if advanced {
                    // https://developer.unico.io/developers/start/environments
                    Field(label: "Identity host", text: $settings.identityHost)
                    Field(label: "API host", text: $settings.apiHost)
                }

                if let error { Card { CodeBlock(error) } }
            }
            .screen {
                Button(sending ? "Verifying…" : "Verify connection", action: verify)
                    .buttonStyle(PrimaryButtonStyle()).disabled(sending)
                Hint("No service account yet? Ask Unico's onboarding team.")
            }
        }
        .background(Color.ground)
        // A .pem has no registered type, so the picker accepts any file and the key check decides.
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
            guard let url = try? result.get() else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            pem = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
    }

    private func connected(_ settings: Settings) -> some View {
        Group {
            VStack(alignment: .leading, spacing: 14) {
                Heading(symbol: "checkmark", ink: .okInk, ground: .okGround, title: "Credentials verified",
                        subtitle: "We got a token from Unico \(settings.environment).")
                Card {
                    KeyValue(key: "Service account", value: settings.account)
                    KeyValue(key: "Tenant ID", value: settings.tenant)
                    KeyValue(key: "Environment", value: settings.environment)
                }
            }
            .screen {
                Button("Continue") {
                    do { try onContinue(settings) } catch { self.error = error.localizedDescription; verified = nil }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .background(Color.ground)
    }

    private func verify() {
        var next = settings
        for keyPath in [\Settings.identityHost, \.apiHost, \.account, \.tenant, \.sdkKey, \.bundleIdentifier] {
            next[keyPath: keyPath] = next[keyPath: keyPath].trimmingCharacters(in: .whitespaces)
        }
        if !pem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            next.privateKeyPem = pem.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard next.isComplete else {
            error = "Fill in every field and add the private key."
            return
        }
        do {
            _ = try parsePrivateKey(next.privateKeyPem)
        } catch {
            self.error = error.localizedDescription
            return
        }
        sending = true
        Task {
            error = await onVerify(next)
            if error == nil { verified = next }
            sending = false
        }
    }
}
