// Navigation and glue. Screens: settings, flows menu, form, journey (native SDK), result, evidence set.
// Everything Unico-specific lives in the other folders; this file wires them together.
import AcessoBio
import SwiftUI

@main
struct UnicoReferenceApp: App {
    var body: some Scene {
        WindowGroup { Root() }
    }
}

private enum Route: Hashable {
    case settings
    case form(Flow)
    case journey(webAppToken: String)
    case result(processId: String)
    case evidenceSet(processId: String)
}

// flows.json ships in the app bundle, from flows/.
private let flows = try! parseFlows(Data(contentsOf: Bundle.main.url(forResource: "flows", withExtension: "json")!))

// DEMO ONLY: the app builds the Unico client on the device. In production, your server does.
private func makeUnico(_ settings: Settings) -> Unico? {
    guard settings.isComplete, let key = try? parsePrivateKey(settings.privateKeyPem) else { return nil }
    return Unico(serviceAccount: settings.serviceAccount, privateKey: key, hosts: settings.hosts)
}

private struct Root: View {
    private let store = SettingsStore()
    @State private var settings: Settings
    @State private var unico: Unico?
    @State private var path: [Route] = []

    init() {
        let settings = store.load()
        _settings = State(initialValue: settings)
        _unico = State(initialValue: makeUnico(settings))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Fixed on every screen: the credentials on this device are for demonstration only.
            Text("Demo mode: the service account key is on this device. In production it lives only on your server.")
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.red.opacity(0.15))

            NavigationStack(path: $path) {
                Group {
                    // Incomplete settings open Settings first.
                    if unico == nil {
                        SettingsScreen(initial: settings, onSave: save)
                    } else {
                        FlowsScreen(flows: flows) { path.append(.form($0)) }
                            .toolbar { Button("Settings") { path.append(.settings) } }
                    }
                }
                .navigationDestination(for: Route.self, destination: screen)
            }
        }
    }

    @ViewBuilder
    private func screen(_ route: Route) -> some View {
        switch route {
        case .settings:
            SettingsScreen(initial: settings, onSave: save)
        case .form(let flow):
            FormScreen(flow: flow) { body in
                do {
                    let response = try await unico!.createProcess(body)
                    guard let webAppToken = (response["process"] as? [String: Any])?["webAppToken"] as? String else {
                        return "No process.webAppToken in the response:\n\(pretty(response))"
                    }
                    path.append(.journey(webAppToken: webAppToken))
                    return nil
                } catch {
                    return describe(error)
                }
            }
        case .journey(let webAppToken):
            NativeSdkJourney(
                webAppToken: webAppToken,
                sdkKey: settings.sdkKey,
                bundleIdentifier: settings.bundleIdentifier,
                // The SDK environment follows the hosts in Settings: PROD hosts open the PROD journey, anything else UAT.
                environment: settings.hosts == .prod ? .PROD : .UAT,
                // Back from the result goes to the flows menu, not to the form or the journey.
                onFinished: { path = [.result(processId: $0)] },
                onBack: { path.removeLast() }
            )
        case .result(let processId):
            ResultScreen(
                unico: unico!,
                processId: processId,
                onEvidenceSet: { path.append(.evidenceSet(processId: processId)) },
                onDone: { path = [] }
            )
        case .evidenceSet(let processId):
            EvidenceSetScreen(unico: unico!, processId: processId)
        }
    }

    private func save(_ saved: Settings) throws {
        try store.save(saved)
        settings = saved
        unico = makeUnico(saved)
        path = []
    }
}
