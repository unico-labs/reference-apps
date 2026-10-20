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

    var isOpening: Bool { if case .opening = self { true } else { false } }
}

// https://developer.unico.io/developers/sdks-and-tools/ios/initialization
// Build this once when the app starts, not when the user taps to start: the SDK's authentication with the backend
// takes a few seconds, and doing it together with the camera opening reads as lag. The app builds it at launch.
// `environment` must match the hosts the process was created on: .UAT or .PROD.
@MainActor
final class NativeSdk {
    let environment: EnvironmentEnum
    // The SDK presents its screens from this controller, which each journey places behind its SwiftUI view.
    let host = UIViewController()
    fileprivate let camera: AcessoBioCameraDelegate
    // AcessoBioManager keeps one delegate for its whole life, so it forwards to whichever journey is on screen.
    fileprivate let listener = SessionListener()
    private let manager: AcessoBioManager

    init(environment: EnvironmentEnum) {
        self.environment = environment
        manager = AcessoBioManager(viewController: host, delegate: listener)!
        manager.setEnvironment(environment)
        camera = manager.build()
    }
}

// https://developer.unico.io/developers/sdks-and-tools/ios/api-reference/callback-listener-interfaces
// The journey on screen sets `session` on the main actor and the SDK reads it from its callbacks; one runs at a time.
fileprivate final class SessionListener: NSObject, AcessoBioManagerDelegate, @unchecked Sendable {
    weak var session: JourneySession?

    func onErrorAcessoBioManager(_ error: ErrorBio!) { session?.fail(error) }
    func onUserClosedCameraManually() { session?.finish(.ended("The journey was closed before it finished.")) }
    func onSystemClosedCameraTimeoutSession() { session?.finish(.ended("The capture session timed out.")) }
    // The SDK switches to manual capture and the journey goes on.
    func onSystemChangedTypeCameraTimeoutFaceInference() {}
}

// `sdkKey` comes from Unico's Onboarding team, linked to `bundleIdentifier` and your Team ID. In a real app that's
// your own Bundle.main.bundleIdentifier; this demo lets Connect override it.
// `flow` and `processId` are only shown on the page behind the camera.
struct NativeSdkJourney: View {
    let webAppToken: String
    let flow: String
    let processId: String
    let sdkKey: String
    let bundleIdentifier: String
    let sdk: NativeSdk
    let onFinished: (_ processId: String) -> Void
    let onBack: () -> Void

    @State private var state = JourneyState.opening
    @State private var session: JourneySession?
    @State private var started = false
    @Environment(\.openURL) private var openURL

    // The page behind the SDK's camera: what the person sees while the journey runs, and after it stops.
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch state {
                case .opening:
                    status("In progress", ink: Color(red: 0.11, green: 0.27, blue: 0.67), ground: Color(red: 0.89, green: 0.93, blue: 0.99))
                    title("Journey in progress", "Finish the journey on the camera screen. This page moves to the result when you are done.")
                // Once the user denies the camera, iOS stops asking, so the way back is the app's page in Settings.
                case .cameraDenied:
                    status("Camera blocked", ink: .secondary, ground: .white, outlined: true)
                    title("Camera access needed", "The journey takes a selfie. Allow the camera in Settings, then try again.")
                case .ended(let message):
                    status("Camera closed", ink: .secondary, ground: .white, outlined: true)
                    title("Journey not finished", message)
                }
                VStack(spacing: 0) {
                    row("Flow", flow)
                    Divider()
                    row("Process ID", processId)
                    Divider()
                    row("Opened with", "Native SDK")
                }
                .padding(.horizontal, 16)
                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.86)))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            switch state {
            case .opening: EmptyView()
            case .cameraDenied:
                actions {
                    action("Open Settings", primary: true) { openURL(URL(string: UIApplication.openSettingsURLString)!) }
                    action("Try again", primary: false) { Task { await start() } }
                }
            // The process stays where the journey stopped, so a new test creates a new one.
            case .ended: actions { action("Start a new test", primary: true, onBack) }
            }
        }
        .background(Color(red: 0.96, green: 0.97, blue: 0.98))
        .background(HostView(controller: sdk.host))
        .navigationBarBackButtonHidden(state.isOpening)
        // onAppear runs again when the SDK's screen goes away, so the journey opens once, behind a flag.
        .onAppear {
            guard !started else { return }
            started = true
            Task { await start() }
        }
    }

    private func status(_ text: String, ink: Color, ground: Color, outlined: Bool = false) -> some View {
        Text(text).font(.caption.bold()).foregroundStyle(ink)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(ground, in: Capsule())
            .overlay(Capsule().stroke(outlined ? Color(white: 0.86) : .clear))
    }

    private func title(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.title2.weight(.heavy))
            Text(text).font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key.uppercased()).font(.caption2.bold()).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.footnote.monospaced())
        }
        .frame(minHeight: 44)
    }

    private func actions<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 10) { content() }
            .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
            .background(.white)
            .overlay(alignment: .top) { Divider() }
    }

    private func action(_ text: String, primary: Bool, _ run: @escaping () -> Void) -> some View {
        Button(action: run) {
            Text(text).font(.body.bold()).frame(maxWidth: .infinity, minHeight: 48)
        }
        .foregroundStyle(primary ? .white : .primary)
        .background(primary ? Color(red: 0.14, green: 0.34, blue: 0.84) : .white, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(primary ? .clear : Color(white: 0.6)))
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
        let session = JourneySession(host: sdk.host, sdkKey: sdkKey, bundleIdentifier: bundleIdentifier, webAppToken: webAppToken) { outcome in
            switch outcome {
            case .finished(let processId): onFinished(processId)
            case .cameraDenied: state = .cameraDenied
            case .ended(let message): state = .ended(message)
            }
        }
        self.session = session
        sdk.listener.session = session
        sdk.camera.prepareSelfieCamera(session, config: session)
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
    private var ended = false

    init(host: UIViewController, sdkKey: String, bundleIdentifier: String, webAppToken: String, onEnd: @escaping (Outcome) -> Void) {
        self.host = host
        self.sdkKey = sdkKey
        self.bundleIdentifier = bundleIdentifier
        self.webAppToken = webAppToken
        self.onEnd = onEnd
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
