// The create-process form. Same fields as web/views/form.ejs; buildProcessBody turns them into the request body.
import SwiftUI

// https://developer.unico.io/developers/api-reference/post-processes (duiType values)
private let duiTypes = [
    "DUI_TYPE_BR_CPF", "DUI_TYPE_MX_CURP", "DUI_TYPE_AR_DNI", "DUI_TYPE_AR_LNC", "DUI_TYPE_AR_PASSPORT",
    "DUI_TYPE_AT_STNR", "DUI_TYPE_BE_NN", "DUI_TYPE_BR_CNPJ", "DUI_TYPE_BR_PASSPORT", "DUI_TYPE_CA_SIN",
    "DUI_TYPE_CH_AHV", "DUI_TYPE_CL_LICENCIA_CONDUCIR", "DUI_TYPE_CL_PASSPORT", "DUI_TYPE_CL_RUN", "DUI_TYPE_CO_CC",
    "DUI_TYPE_CO_LICENCIA_CONDUCCION", "DUI_TYPE_CO_NIT", "DUI_TYPE_CO_PASSPORT", "DUI_TYPE_DE_IDNR", "DUI_TYPE_DK_CPR",
    "DUI_TYPE_EC_NI", "DUI_TYPE_ES_DNI", "DUI_TYPE_ES_NIE", "DUI_TYPE_FI_HETU", "DUI_TYPE_FR_SPI", "DUI_TYPE_GB_NINO",
    "DUI_TYPE_GT_CUI", "DUI_TYPE_ID_NIK", "DUI_TYPE_IE_PPSN", "DUI_TYPE_IT_CF", "DUI_TYPE_LK_NIC",
    "DUI_TYPE_LU_MATRICULE", "DUI_TYPE_MX_LICENCIA_CONDUCIR", "DUI_TYPE_MX_RFC_PERSONA_FISICA", "DUI_TYPE_NG_BVN",
    "DUI_TYPE_NG_BVN_TOKEN", "DUI_TYPE_NG_NIN", "DUI_TYPE_NG_NIN_TOKEN", "DUI_TYPE_NL_BSN", "DUI_TYPE_NO_FNR",
    "DUI_TYPE_PE_DNI", "DUI_TYPE_PE_PASSPORT", "DUI_TYPE_PE_RUC", "DUI_TYPE_PL_PESEL", "DUI_TYPE_PT_NIF",
    "DUI_TYPE_SE_PNR", "DUI_TYPE_SE_SAMORDNINGSNUMMER", "DUI_TYPE_TR_TCKN", "DUI_TYPE_US_DRIVER_LICENSE",
    "DUI_TYPE_US_ID_CARD", "DUI_TYPE_US_PASSPORT", "DUI_TYPE_US_PASSPORT_CARD", "DUI_TYPE_US_POLYCARBONATE_PASSPORT",
    "DUI_TYPE_US_SSN", "DUI_TYPE_UY_CI", "DUI_TYPE_ZZ_EMAIL", "DUI_TYPE_ZZ_PHONE_NUMBER",
]
private let documentPurposes = [
    "DOCUMENT_PURPOSE_ONBOARDING", "DOCUMENT_PURPOSE_CREDIT_PROCESS", "DOCUMENT_PURPOSE_CAR_PURCHASE",
    "DOCUMENT_PURPOSE_PAY_BY_PAYCHECK", "DOCUMENT_PURPOSE_FGTS",
]
private let useCases = ["USE_CASE_LOGIN", "USE_CASE_FIN_TRANSACTIONS"]
private let purposes = ["", "biometryonboarding", "creditprocess", "carpurchase", "ageverification"]
private let currencies = ["", "BRL", "MXN", "USD"]
private let locales = ["ptBr", "enUs", "esMx"]

// The native SDK handles the return in-app, so the docs ask for "/" as the callbackUri.
private let callbackUri = "/"

// `onSubmit` creates the process and opens the journey. It returns an error to show, or nil when it went on.
struct FormScreen: View {
    let flow: Flow
    let onSubmit: (sending [String: Any]) async -> String?

    @State private var fields = [
        "duiType": duiTypes[0], "documentPurpose": documentPurposes[0], "useCase": useCases[0], "locale": locales[0],
    ]
    @State private var documents: [URL] = []
    @State private var pickingDocuments = false
    @State private var error: String?
    @State private var sending = false

    var body: some View {
        Form {
            Section {
                Text(flow.capabilities.joined(separator: " · ")).font(.caption)
                Text("Use your own document. There are no test documents: the journey checks a real face against it.")
                if let error { Text(error).font(.caption.monospaced()).foregroundStyle(.red).textSelection(.enabled) }
            }

            Section("Person") {
                picker("Document type", "duiType", duiTypes)
                input("duiValue", "Your document", hint: "Numbers only, no formatting")
                input("friendlyName", "Name", hint: "Optional")
                input("email", "Email", hint: "Optional", keyboard: .emailAddress)
                input("phone", "Phone", hint: "Optional, e.g. 5511999999999", keyboard: .phonePad)
            }

            if flow.extraFields.contains("document") {
                Section("Document for Face Document Match") {
                    Button(documents.isEmpty ? "Pick document images (optional)" : "\(documents.count) file(s) picked") {
                        pickingDocuments = true
                    }
                    picker("Document purpose", "documentPurpose", documentPurposes)
                }
            }

            if flow.extraFields.contains("useCase") {
                Section("Smart Revalidation") {
                    picker("useCase", "useCase", useCases)
                    input("referenceProcessId", "Onboarding process ID", hint: "Process to revalidate against")
                }
            }

            Section("Advanced") {
                input("expiresIn", "expiresIn", hint: "3600s (default: 7 days)")
                picker("purpose", "purpose", purposes)
                input("companyName", "contextualization.company_name")
                picker("contextualization.currency", "currency", currencies)
                input("price", "contextualization.price", keyboard: .numbersAndPunctuation)
                picker("reason locale", "locale", locales)
                input("reason", "contextualization reason")
            }

            Section("Create process and open with") {
                Button("Native SDK", action: submit)
                    .disabled(sending || fields["duiValue", default: ""].isEmpty)
            }
        }
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .navigationTitle(flow.id)
        .fileImporter(isPresented: $pickingDocuments, allowedContentTypes: [.image, .pdf], allowsMultipleSelection: true) {
            documents = (try? $0.get()) ?? []
        }
    }

    private func submit() {
        sending = true
        Task {
            do {
                let files = try documents.map(readBase64)
                error = await onSubmit(buildProcessBody(flow: flow, fields: fields, documentFiles: files, callbackUri: callbackUri))
            } catch {
                self.error = "Could not read a document file: \(error.localizedDescription)"
            }
            sending = false
        }
    }

    private func input(_ name: String, _ label: String, hint: String = "", keyboard: UIKeyboardType = .default) -> some View {
        LabeledContent(label) {
            TextField(hint, text: Binding { fields[name, default: ""] } set: { fields[name] = $0 })
                .keyboardType(keyboard)
                .multilineTextAlignment(.trailing)
        }
    }

    private func picker(_ label: String, _ name: String, _ options: [String]) -> some View {
        Picker(label, selection: Binding { fields[name, default: ""] } set: { fields[name] = $0 }) {
            ForEach(options, id: \.self) { Text($0.isEmpty ? "Not set" : $0).tag($0) }
        }
    }
}

// Files from the picker live outside the app's sandbox and are readable only inside this access window.
private func readBase64(_ url: URL) throws -> String {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    return try Data(contentsOf: url).base64EncodedString()
}
