// The evidence set: one GET when the user opens it, drawn in the app with PDFKit.
// It holds biometric data, so it isn't handed to another app (no share sheet, no Quick Look) and no copy is kept:
// the PDF lives in memory only while this screen is open.
import PDFKit
import SwiftUI

struct EvidenceSetScreen: View {
    let unico: Unico
    let processId: String

    @State private var pdf: PDFDocument?
    @State private var error: String?

    var body: some View {
        Group {
            if let pdf {
                PDFKitView(document: pdf)
            } else if let error {
                ScrollView { Text(error).font(.caption.monospaced()).textSelection(.enabled).padding() }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Evidence set")
        // Nothing covers this screen, so .task runs once.
        .task {
            do {
                // contentType comes back as "x-pdf"; fileContents is a base64 PDF, so contentType is ignored here.
                let response = try await unico.getEvidenceSet(processId)
                guard let base64 = response["fileContents"] as? String, let data = Data(base64Encoded: base64),
                      let document = PDFDocument(data: data) else {
                    error = "fileContents is not a base64 PDF:\n\(pretty(response))"
                    return
                }
                pdf = document
            } catch {
                self.error = describe(error)
            }
        }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = document
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
