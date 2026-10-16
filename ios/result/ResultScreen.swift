// The result after onSuccess(processId): the process as the API returns it, without interpreting it, plus the selfie
// and a button for the evidence set. One GET each, once. This repo's rule: no polling and no webhook.
import SwiftUI
import UIKit

// Indented for reading. JSONSerialization doesn't keep key order, so keys come out sorted.
func pretty(_ json: Any) -> String {
    let data = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    return data.map { String(decoding: $0, as: UTF8.self) } ?? String(describing: json)
}

// Errors are shown raw too: status and body exactly as Unico returned them, only indented when the body is JSON.
func describe(_ error: Error) -> String {
    guard let error = error as? UnicoError else { return String(describing: error) }
    let json = try? JSONSerialization.jsonObject(with: Data(error.body.utf8))
    return "HTTP \(error.status)\n\(json.map(pretty) ?? error.body)"
}

private struct Loaded {
    let process: String
    let selfie: UIImage?
    let selfieError: String?
}

struct ResultScreen: View {
    let unico: Unico
    let processId: String
    let onEvidenceSet: () -> Void
    let onDone: () -> Void

    @State private var loaded: Loaded?
    @State private var started = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let loaded {
                    Text("GET /client/v1/process/{id}").font(.headline)
                    Text(loaded.process).font(.caption.monospaced()).textSelection(.enabled)

                    Text("GET /client/v1/process/{id}/selfie").font(.headline)
                    if let selfie = loaded.selfie {
                        Image(uiImage: selfie).resizable().scaledToFit().accessibilityLabel("Selfie captured in the journey")
                    }
                    if let error = loaded.selfieError { Text(error).font(.caption.monospaced()).textSelection(.enabled) }

                    Text("GET /client/v1/process/{id}/evidenceset").font(.headline)
                    Button("Open evidence set (PDF)", action: onEvidenceSet).buttonStyle(.borderedProminent)

                    Button("Run another flow", action: onDone).buttonStyle(.bordered)
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle("Result")
        // onAppear runs again when the user comes back from the evidence set, and .task would cancel a request
        // in flight when the screen goes away. So the load runs once, in its own Task, behind a flag.
        .onAppear {
            guard !started else { return }
            started = true
            Task { loaded = await load(unico, processId) }
        }
    }
}

private func load(_ unico: Unico, _ processId: String) async -> Loaded {
    async let process: String = {
        do { return pretty(try await unico.getProcess(processId)) } catch { return describe(error) }
    }()
    async let selfie: (UIImage?, String?) = {
        do {
            let response = try await unico.getSelfie(processId)
            guard let base64 = response["fileContents"] as? String, let data = Data(base64Encoded: base64),
                  let image = UIImage(data: data) else { return (nil, "fileContents is not a base64 image:\n\(pretty(response))") }
            return (image, nil)
        } catch {
            return (nil, describe(error))
        }
    }()
    let (image, selfieError) = await selfie
    return Loaded(process: await process, selfie: image, selfieError: selfieError)
}
