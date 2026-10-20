// The result after onSuccess(processId): a heading that names the result in words, the process as the API returns
// it, the selfie and the evidence set. One GET each, once. This repo's rule: no polling and no webhook.
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
    let process: [String: Any]?
    let raw: String
    let selfie: UIImage?
    let selfieError: String?
}

struct ResultScreen: View {
    let unico: Unico
    let processId: String
    let onEvidenceSet: () -> Void
    let onStepUp: () -> Void
    let onDone: () -> Void

    @State private var loaded: Loaded?
    @State private var started = false
    @State private var viewingSelfie = false

    var body: some View {
        Group {
            if let loaded { content(loaded) } else { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
        }
        .background(Color.ground)
        // onAppear runs again when the user comes back from the evidence set, and .task would cancel a request
        // in flight when the screen goes away. So the load runs once, in its own Task, behind a flag.
        .onAppear {
            guard !started else { return }
            started = true
            Task { loaded = await load(unico, processId) }
        }
    }

    private func content(_ loaded: Loaded) -> some View {
        Group {
            VStack(alignment: .leading, spacing: 14) {
                if let process = loaded.process {
                    let verdict = verdict(process)
                    let (symbol, ink, ground): (String, Color, Color) = switch verdict.tone {
                    case .ok: ("checkmark", .okInk, .okGround)
                    case .bad: ("xmark", .badInk, .badGround)
                    case .neutral: ("minus", .muted, .line)
                    }
                    let subtitle = [process["flow"] as? String, durationSeconds(process).map { "\($0) s" }].compactMap { $0 }
                    Heading(symbol: symbol, ink: ink, ground: ground, title: verdict.title,
                            subtitle: subtitle.isEmpty ? nil : subtitle.joined(separator: " · "))
                    Card {
                        KeyValue(key: "Process ID", value: processId)
                        KeyValue(key: "State", value: short(process["state"]) ?? "")
                        KeyValue(key: "Result", value: short(process["result"]) ?? "")
                    }
                } else {
                    Heading(symbol: "minus", ink: .muted, ground: .line, title: "Result")
                }

                Card {
                    Lab("Response")
                    CodeBlock(loaded.raw)
                }

                Card {
                    attachment("Selfie", action: loaded.selfie == nil ? nil : "View", thumb: loaded.selfie) { viewingSelfie = true }
                    if let error = loaded.selfieError { CodeBlock(error) }
                    Divider()
                    attachment("Evidence set (PDF)", action: "Open", thumb: nil, run: onEvidenceSet)
                }
            }
            .screen {
                Button("Try step-up on this process", action: onStepUp).buttonStyle(PrimaryButtonStyle())
                Button("Run another flow", action: onDone).buttonStyle(SecondaryButtonStyle())
            }
        }
        .sheet(isPresented: $viewingSelfie) {
            if let selfie = loaded.selfie {
                Image(uiImage: selfie).resizable().scaledToFit().padding()
                    .accessibilityLabel("Selfie captured in the journey")
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private func attachment(_ name: String, action: String?, thumb: UIImage?, run: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Group {
                if let thumb { Image(uiImage: thumb).resizable().scaledToFill() } else { Color.ground }
            }
            .frame(width: 40, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            Text(name).font(.body.bold()).foregroundStyle(Color.ink)
            Spacer()
            if let action { Button(action, action: run).font(.subheadline.bold()).foregroundStyle(Color.accent) }
        }
        .frame(minHeight: 56)
    }
}

private func load(_ unico: Unico, _ processId: String) async -> Loaded {
    async let process: ([String: Any]?, String) = {
        do {
            let response = try await unico.getProcess(processId)
            return (response["process"] as? [String: Any], pretty(response))
        } catch {
            return (nil, describe(error))
        }
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
    let (json, raw) = await process
    return Loaded(process: json, raw: raw, selfie: image, selfieError: selfieError)
}
