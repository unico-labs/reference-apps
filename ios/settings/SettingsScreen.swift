// DEMO ONLY: the settings screen. In production none of this is on the device; your server holds the credentials.
import SwiftUI

struct SettingsScreen: View {
    let initial: Settings
    let onSave: (Settings) throws -> Void

    @State private var settings: Settings
    // The stored key is never shown again. Leave the field empty to keep it.
    @State private var pem = ""
    @State private var importing = false
    @State private var error: String?

    init(initial: Settings, onSave: @escaping (Settings) throws -> Void) {
        self.initial = initial
        self.onSave = onSave
        _settings = State(initialValue: initial)
    }

    var body: some View {
        Form {
            Section {
                TextField("Identity host", text: $settings.identityHost)
                TextField("API host", text: $settings.apiHost)
            } header: {
                Text("Environment")
            } footer: {
                Text("Hosts come filled in with UAT. See developer.unico.io/developers/start/environments.")
            }

            Section {
                TextField("Unique account name", text: $settings.account)
                TextField("Tenant ID", text: $settings.tenant)
            } header: {
                Text("Credentials")
            } footer: {
                // The JWT iss is built from these two: https://developer.unico.io/developers/start/authentication
                Text(settings.account.isEmpty || settings.tenant.isEmpty
                    ? "iss: <account_name>@<tenant_id>.iam.acesso.io"
                    : "iss: \(settings.serviceAccount)")
            }

            Section("Private key (.pem)") {
                Button("Import file") { importing = true }
                TextField(
                    initial.privateKeyPem.isEmpty ? "Or paste it here" : "Saved. Paste or import to replace it",
                    text: $pem, axis: .vertical
                )
                .font(.caption.monospaced())
                .lineLimit(4...8)
            }

            Section {
                TextField("SDK key", text: $settings.sdkKey)
                TextField("Bundle Identifier", text: $settings.bundleIdentifier)
            } footer: {
                Text("The SDK key is issued for a Bundle Identifier and Team ID. This build is \(Bundle.main.bundleIdentifier ?? ""). Change it only to try a key issued for another ID.")
            }

            if let error { Text(error).foregroundStyle(.red) }

            Button("Save", action: save)
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .navigationTitle("Settings")
        // A .pem has no registered type, so the picker accepts any file and the key check on save decides.
        .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
            guard let url = try? result.get() else { return }
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            pem = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        }
    }

    private func save() {
        var next = settings
        for keyPath in [\Settings.identityHost, \.apiHost, \.account, \.tenant, \.sdkKey] {
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
            try onSave(next)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
