// Native SDK: https://developer.unico.io/developers/sdks-and-tools/ios/capture-flow/user-journeys
// Opens Unico's journey with the process's webAppToken and hands back the processId from onSuccess.
// The journey always runs in the SDK: never in a WebView, SFSafariViewController, ASWebAuthenticationSession or Safari.
// Self-contained: the mode uses nothing from the other folders. It takes plain values and returns a processId.
import AVFoundation
@preconcurrency import AcessoBio
import SwiftUI
import UIKit

// https://developer.unico.io/developers/sdks-and-tools/ios/error-handling
private let cameraAccessDenied = 73706

private enum JourneyState {
    case opening
    case cameraDenied
    case ended(String)
}

// `sdkKey` comes from Unico's Onboarding team, linked to `bundleIdentifier` and your Team ID. In a real app that's
// your own Bundle.main.bundleIdentifier; this demo lets Settings override it.
// `environment` must match the hosts the process was created on: .UAT or .PROD.
struct NativeSdkJourney: View {
    let webAppToken: String
    let sdkKey: String
    let bundleIdentifier: String
    let environment: EnvironmentEnum
    let onFinished: (_ processId: String) -> Void
    let onBack: () -> Void

    @State private var state = JourneyState.opening
    @State private var session: JourneySession?
    @State private var started = false
    // The SDK presents its screens from this controller, which sits behind the SwiftUI view.
    @State private var host = UIViewController()
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch state {
            case .opening:
                Text("Opening the journey").font(.title2)
                ProgressView()
            // Once the user denies the camera, iOS stops asking, so the way back is the app's page in Settings.
            case .cameraDenied:
                Text("Camera access needed").font(.title2)
                Text("The journey takes a selfie. Allow the camera in Settings, then try again.")
                Button("Open Settings") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                    .buttonStyle(.borderedProminent)
                Button("Try again") { Task { await start() } }.buttonStyle(.bordered)
                Button("Back", action: onBack).buttonStyle(.bordered)
            case .ended(let message):
                Text("Journey not finished").font(.title2)
                Text(message)
                Button("Back", action: onBack).buttonStyle(.bordered)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HostView(controller: host))
        .navigationTitle("Journey")
        // onAppear runs again when the SDK's screen goes away, so the journey opens once, behind a flag.
        .onAppear {
            guard !started else { return }
            started = true
            Task { await start() }
        }
    }

    // The app asks for the camera before opening the SDK. Info.plist carries NSCameraUsageDescription:
    // https://developer.unico.io/developers/sdks-and-tools/ios/installation
    private func start() async {
        state = .opening
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: open()
        case .notDetermined: if await AVCaptureDevice.requestAccess(for: .video) { open() } else { state = .cameraDenied }
        default: state = .cameraDenied
        }
    }

    private func open() {
        let session = JourneySession(host: host, sdkKey: sdkKey, bundleIdentifier: bundleIdentifier, webAppToken: webAppToken) { outcome in
            switch outcome {
            case .finished(let processId): onFinished(processId)
            case .cameraDenied: state = .cameraDenied
            case .ended(let message): state = .ended(message)
            }
        }
        self.session = session
        session.open(environment: environment)
    }
}

// The SDK reports through Objective-C delegates and may call them off the main thread, so each callback
// copies the plain values it needs and hops to the main actor.
@MainActor
private final class JourneySession: NSObject {
    enum Outcome {
        case finished(processId: String)
        case cameraDenied
        case ended(String)
    }

    private let host: UIViewController
    private let sdkKey: String
    private let bundleIdentifier: String
    private let webAppToken: String
    private let onEnd: (Outcome) -> Void
    private var manager: AcessoBioManager?
    private var ended = false

    init(host: UIViewController, sdkKey: String, bundleIdentifier: String, webAppToken: String, onEnd: @escaping (Outcome) -> Void) {
        self.host = host
        self.sdkKey = sdkKey
        self.bundleIdentifier = bundleIdentifier
        self.webAppToken = webAppToken
        self.onEnd = onEnd
    }

    // https://developer.unico.io/developers/sdks-and-tools/ios/initialization
    // The docs suggest building the SDK at app start, since its first authentication takes a few seconds.
    // It's built here so the whole mode stays in this folder.
    func open(environment: EnvironmentEnum) {
        let manager = AcessoBioManager(viewController: host, delegate: self)!
        manager.setEnvironment(environment)
        manager.build().prepareSelfieCamera(self, config: self)
        self.manager = manager
    }

    // The SDK leaves closing its screen to the caller, so whatever it presented is dismissed here:
    // https://developer.unico.io/developers/sdks-and-tools/ios/resources/known-issues
    fileprivate func end(_ outcome: Outcome) {
        // One ending can fire more than one callback (an error, then the camera closing).
        guard !ended else { return }
        ended = true
        if host.presentedViewController != nil {
            host.dismiss(animated: true) { [onEnd] in onEnd(outcome) }
        } else {
            onEnd(outcome)
        }
    }

    nonisolated fileprivate func finish(_ outcome: Outcome) {
        Task { @MainActor in self.end(outcome) }
    }

    nonisolated fileprivate func fail(_ error: ErrorBio?) {
        let code = error?.code ?? 0
        let description = error?.desc ?? ""
        finish(code == cameraAccessDenied ? .cameraDenied : .ended("SDK error \(code): \(description)"))
    }
}

extension JourneySession: AcessoBioConfigDataSource {
    nonisolated func getBundleIdentifier() -> String { bundleIdentifier }
    nonisolated func getHostKey() -> String { sdkKey }
}

// https://developer.unico.io/developers/sdks-and-tools/ios/api-reference/callback-listener-interfaces
extension JourneySession: AcessoBioManagerDelegate {
    nonisolated func onErrorAcessoBioManager(_ error: ErrorBio!) { fail(error) }
    nonisolated func onUserClosedCameraManually() { finish(.ended("The journey was closed before it finished.")) }
    nonisolated func onSystemClosedCameraTimeoutSession() { finish(.ended("The capture session timed out.")) }
    // The SDK switches to manual capture and the journey goes on.
    nonisolated func onSystemChangedTypeCameraTimeoutFaceInference() {}
}

extension JourneySession: SelfieCameraDelegate {
    nonisolated func onCameraReady(_ cameraOpener: AcessoBioCameraOpenerDelegate!) {
        // The opener isn't Sendable; it's only handed to the main actor to present the journey.
        nonisolated(unsafe) let opener = cameraOpener
        Task { @MainActor in opener?.open(self, webAppToken: self.webAppToken) }
    }

    nonisolated func onCameraFailed(_ message: ErrorPrepare!) { fail(message) }
}

// https://developer.unico.io/developers/sdks-and-tools/ios/capture-flow/receiving-the-result
extension JourneySession: AcessoBioSelfieDelegate {
    nonisolated func onSuccess(_ successResult: SuccessResult!) {
        let processId = successResult.processId
        finish(.finished(processId: processId))
    }

    nonisolated func onErrorSelfie(_ errorBio: ErrorBio!) { fail(errorBio) }

    // Dual API only. The protocol requires it; a Unico API journey doesn't use its result.
    nonisolated func onSuccessSelfie(_ result: SelfieResult!) {}
}

private struct HostView: UIViewControllerRepresentable {
    let controller: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
