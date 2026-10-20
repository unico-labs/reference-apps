// Navigation and glue. Screens: Connect (settings), Run a flow, journey (native SDK), result, evidence set.
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
    case journey(webAppToken: String, flow: String, processId: String)
    case result(processId: String)
    case evidenceSet(processId: String)
}

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
    // The last journey finished here, offered as the reference for a step-up.
    @State private var lastProcessId: String?
    @State private var stepUp = false
    // A new value starts a fresh form, for Run another flow and Try step-up.
    @State private var formId = UUID()

    init() {
        let settings = store.load()
        _settings = State(initialValue: settings)
        _unico = State(initialValue: makeUnico(settings))
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                // Incomplete settings open Connect first.
                if unico == nil {
                    connect.bar("Connect")
                } else {
                    FormScreen(reference: lastProcessId, stepUp: stepUp, onSubmit: submit)
                        .id(formId)
                        .bar("Run a flow") { pill }
                }
            }
            .navigationDestination(for: Route.self, destination: screen)
        }
        .tint(.accent)
    }

    private var connect: some View {
        SettingsScreen(
            initial: settings,
            onVerify: { next in
                // A token proves the account, tenant and key; it says nothing about the account's flows.
                do {
                    let key = try parsePrivateKey(next.privateKeyPem)
                    _ = try await Unico(serviceAccount: next.serviceAccount, privateKey: key, hosts: next.hosts).accessToken()
                    return nil
                } catch {
                    return describe(error)
                }
            },
            onContinue: save
        )
    }

    private var pill: some View {
        Button { path.append(.settings) } label: {
            Pill(text: "✓ \(settings.environment) · \(settings.account)", ink: .okInk, ground: .okGround)
        }
    }

    @ViewBuilder
    private func screen(_ route: Route) -> some View {
        switch route {
        case .settings:
            connect.bar("Connect")
        case .journey(let webAppToken, let flow, let processId):
            NativeSdkJourney(
                webAppToken: webAppToken,
                flow: flow,
                processId: processId,
                sdkKey: settings.sdkKey,
                bundleIdentifier: settings.bundleIdentifier,
                // The SDK environment follows the hosts in Connect: PROD hosts open the PROD journey, anything else UAT.
                environment: settings.hosts == .prod ? .PROD : .UAT,
                onFinished: { processId in
                    // Only a finished journey is offered as the reference for a step-up.
                    lastProcessId = processId
                    // Back from the result goes to the form, not to the journey.
                    path = [.result(processId: processId)]
                },
                onBack: { path.removeLast() }
            )
            .bar("Run a flow") { pill }
        case .result(let processId):
            ResultScreen(
                unico: unico!,
                processId: processId,
                onEvidenceSet: { path.append(.evidenceSet(processId: processId)) },
                onStepUp: { startOver(stepUp: true) },
                onDone: { startOver(stepUp: false) }
            )
            .bar("Result") { pill }
        case .evidenceSet(let processId):
            EvidenceSetScreen(unico: unico!, processId: processId).bar("Evidence set")
        }
    }

    private func submit(_ body: sending [String: Any]) async -> String? {
        let flow = body["flow"] as? String ?? ""
        do {
            let response = try await unico!.createProcess(body)
            let process = response["process"] as? [String: Any]
            guard let webAppToken = process?["webAppToken"] as? String, let id = process?["id"] as? String else {
                return "No process.webAppToken in the response:\n\(pretty(response))"
            }
            path.append(.journey(webAppToken: webAppToken, flow: flow, processId: id))
            return nil
        } catch {
            return describe(error)
        }
    }

    private func startOver(stepUp: Bool) {
        self.stepUp = stepUp
        formId = UUID()
        path = []
    }

    private func save(_ saved: Settings) throws {
        try store.save(saved)
        settings = saved
        unico = makeUnico(saved)
        path = []
    }
}

private extension View {
    // The top bar: the screen's title and, once connected, the environment and account on the right.
    func bar<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // The pill carries its own background, so on iOS 26 it skips the toolbar's glass.
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .topBarTrailing) { trailing() }.sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarTrailing) { trailing() }
                }
            }
            .toolbarBackground(.white, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
    }
}
