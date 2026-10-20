// DEMO ONLY: the setup screens. In production none of this is on the device; your server holds the credentials.
// Step 1 asks for the API credentials and checks them, step 2 for the SDK key; nothing is saved until step 2.
import SwiftUI

extension Settings {
    var environment: String { hosts == .prod ? "PROD" : "UAT" }
}

// Step 1. `onVerify` asks Unico for an access token with these settings. It returns an error to show, or nil when
// the token came back; then `onVerified` gets the settings typed here.
struct CredentialsScreen: View {
    let initial: Settings
    let onVerify: (Settings) async -> String?
    let onVerified: (Settings) -> Void

    @State private var settings: Settings
    // The stored key is never shown again. Leave the field empty to keep it.
    @State private var pem = ""
    @State private var importing = false
    @State private var advanced = false
    @State private var sending = false
    @State private var error: String?

    init(initial: Settings, onVerify: @escaping (Settings) async -> String?, onVerified: @escaping (Settings) -> Void) {
        self.initial = initial
        self.onVerify = onVerify
        self.onVerified = onVerified
        _settings = State(initialValue: initial)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SetupProgress(label: "Step 1 of 2", filled: 1)
            Title(title: "API credentials", subtitle: "Used to create the process when you start a test.")
            Text("Demo only. Credentials stay on this device. In your own app, keep them on your backend.")
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
                    initial.privateKeyPem.isEmpty ? "-----BEGIN PRIVATE KEY-----" : "Key added. Paste or import to replace it",
                    text: $pem, axis: .vertical
                )
                .font(.caption.monospaced())
                .lineLimit(3...8)
                .padding(.vertical, 12)
                .fieldStyle()
                Hint("Paste it or import the file. Stored in the Keychain.")
            }
            Button("Import .pem file") { importing = true }.buttonStyle(SecondaryButtonStyle())

            Hint("Unico provides all three when it creates your service account. Never ship the private key inside a mobile app.")
            DocLink(title: "Authentication guide ↗", url: "https://developer.unico.io/developers/start/authentication")

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
            Button(sending ? "Verifying…" : "Verify credentials", action: verify)
                .buttonStyle(PrimaryButtonStyle()).disabled(sending)
        }
        // A .pem has no registered type, so the picker accepts any file and the key check decides.
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
            guard let url = try? result.get() else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            pem = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
    }

    private func verify() {
        var next = settings
        for keyPath in [\Settings.identityHost, \.apiHost, \.account, \.tenant] {
            next[keyPath: keyPath] = next[keyPath: keyPath].trimmingCharacters(in: .whitespaces)
        }
        if !pem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            next.privateKeyPem = pem.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard next.hasCredentials else {
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
            sending = false
            if error == nil { onVerified(next) }
        }
    }
}

// Step 1, done: what Unico accepted.
struct ConnectedScreen: View {
    let settings: Settings
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SetupProgress(label: "Step 1 of 2 · done", filled: 1)
            Heading(symbol: "checkmark", ink: .okInk, ground: .okGround, title: "Connected to the API",
                    subtitle: "Unico \(settings.environment) accepted your credentials.")
            Card {
                KeyValue(key: "Service account", value: settings.account)
                KeyValue(key: "Tenant ID", value: settings.tenant)
                KeyValue(key: "Environment", value: settings.environment)
            }
            Text("One more step: the SDK settings, so the camera experience can open.")
                .font(.subheadline).foregroundStyle(Color.muted)
        }
        .screen {
            Button("Continue to SDK settings", action: onContinue).buttonStyle(PrimaryButtonStyle())
        }
    }
}

// Step 2. The SDK key is checked only when the camera opens; `onSave` stores everything.
struct SdkSettingsScreen: View {
    let onSave: (Settings) throws -> Void

    @State private var settings: Settings
    @State private var error: String?

    init(settings: Settings, onSave: @escaping (Settings) throws -> Void) {
        self.onSave = onSave
        _settings = State(initialValue: settings)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SetupProgress(label: "Step 2 of 2", filled: 2)
            Title(title: "SDK settings", subtitle: "Used to open the camera experience.")
            Field(label: "SDK key", placeholder: "Paste the key Unico issued", text: $settings.sdkKey)
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel(text: "App ID")
                // Unico links the SDK key to the app's Bundle Identifier: https://developer.unico.io/developers/sdks-and-tools/ios/installation/specific-setup
                Text(Bundle.main.bundleIdentifier ?? "")
                    .foregroundStyle(Color.muted)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fieldStyle()
                Hint("Bundle ID of this app. The SDK key must be issued for it.")
            }
            Hint("Ask Unico's Onboarding team for an SDK key linked to your app ID. We don't check it here. If the camera doesn't open, review the key and the app ID.")
            DocLink(title: "iOS setup ↗", url: "https://developer.unico.io/developers/sdks-and-tools/ios/initialization")
            if let error { Card { CodeBlock(error) } }
        }
        .screen {
            Button("Save and continue") {
                settings.sdkKey = settings.sdkKey.trimmingCharacters(in: .whitespaces)
                do { try onSave(settings) } catch { self.error = error.localizedDescription }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(settings.sdkKey.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }
}

// "Step 1 of 2" over a two-part bar.
private struct SetupProgress: View {
    let label: String
    let filled: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Lab(label)
            HStack(spacing: 6) {
                ForEach(0..<2, id: \.self) { Capsule().fill($0 < filled ? Color.accent : Color.line).frame(height: 4) }
            }
        }
    }
}

private struct Title: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title2.weight(.heavy)).foregroundStyle(Color.ink)
            Hint(subtitle)
        }
    }
}
