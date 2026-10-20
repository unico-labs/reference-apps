// Run a flow: the create-process form, the Customize sheet and the error screen. Same fields as web/views/form.ejs;
// buildProcessBody turns them into the request body.
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
    "", "DOCUMENT_PURPOSE_ONBOARDING", "DOCUMENT_PURPOSE_CREDIT_PROCESS", "DOCUMENT_PURPOSE_CAR_PURCHASE",
    "DOCUMENT_PURPOSE_PAY_BY_PAYCHECK", "DOCUMENT_PURPOSE_FGTS",
]
// The examples in the Create Process docs.
private let useCases = ["USE_CASE_LOGIN", "USE_CASE_FIN_TRANSACTIONS"]
private let purposes = ["", "biometryonboarding", "creditprocess", "carpurchase", "ageverification"]
private let currencies = ["", "BRL", "MXN", "USD"]
private let locales = ["ptBr", "enUs", "esMx"]

// The native SDK handles the return in-app, so the docs ask for "/" as the callbackUri.
private let callbackUri = "/"

// `onSubmit` creates the process and opens the journey. It returns an error to show, or nil when it went on.
// `reference` is the last finished journey: it fills the reference field, turned on when `stepUp` asks for it.
struct FormScreen: View {
    let reference: String?
    let onSubmit: (sending [String: Any]) async -> String?

    @State private var fields: [String: String]
    @State private var documents: [URL] = []
    @State private var pickingDocuments = false
    @State private var customizing = false
    @State private var error: String?
    @State private var sending = false

    init(reference: String?, stepUp: Bool, onSubmit: @escaping (sending [String: Any]) async -> String?) {
        self.reference = reference
        self.onSubmit = onSubmit
        _fields = State(initialValue: [
            "duiType": duiTypes[0], "useCase": useCases[0], "locale": locales[0],
            "referenceProcessId": reference ?? "", "withReferences": String(stepUp),
        ])
    }

    var body: some View {
        // On the error screen the form waits behind, still filled in. Try again brings it back.
        if let error { failed(error) } else { form }
    }

    private var form: some View {
        // The preview shows the body the app will send; files stand in as placeholders.
        let preview = buildProcessBody(fields: fields, documentFiles: documents.map { _ in "<file as base64>" }, callbackUri: callbackUri)
        return Group {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Which flow do you want to test?").font(.title2.weight(.heavy)).foregroundStyle(Color.ink)
                    Hint("Type the flow name Unico gave you. If your account doesn't have it, the test fails and we show the API error.")
                }
                Field(label: "Flow", api: "flow", required: true, placeholder: "e.g. idlive_r2",
                      hint: "Flow names are listed on the Flows page of the Unico docs.", mono: true, text: bind("flow"))
                Select(label: "Document type", api: "person.duiType", options: duiTypes, selection: bind("duiType"))
                Field(label: "Document number", api: "person.duiValue", placeholder: "Numbers only, no formatting",
                      hint: "The person's own document. Leave it empty if the flow doesn't ask for one.", text: bind("duiValue"))
                VStack(alignment: .leading, spacing: 8) {
                    Lab("Request your backend sends")
                    CodeBlock("POST /client/v1/process\n\(pretty(preview))")
                }
            }
            .screen {
                HStack(spacing: 10) {
                    Button("Customize") { customizing = true }.buttonStyle(SecondaryButtonStyle(fill: false))
                    Button(sending ? "Starting…" : "Start test", action: submit)
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(sending || fields["flow", default: ""].trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .background(Color.ground)
        .sheet(isPresented: $customizing) { customize }
        .fileImporter(isPresented: $pickingDocuments, allowedContentTypes: [.image, .pdf], allowsMultipleSelection: true) {
            documents = (try? $0.get()) ?? []
        }
    }

    private var customize: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Customize request").font(.title3.weight(.heavy)).foregroundStyle(Color.ink)
                Spacer()
                Button { customizing = false } label: { Image(systemName: "xmark").font(.body.bold()).foregroundStyle(Color.muted) }
                    .frame(width: 44, height: 44).accessibilityLabel("Close")
            }
            .padding(.leading, 16).padding(.trailing, 4).padding(.top, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Field(label: "Name", api: "person.friendlyName", placeholder: "Full name (optional)", text: bind("friendlyName"))
                    HStack(alignment: .top, spacing: 12) {
                        Field(label: "Email", api: "person.email", keyboard: .emailAddress, text: bind("email"))
                        Field(label: "Phone", api: "person.phone", placeholder: "5511999999999", keyboard: .phonePad, text: bind("phone"))
                    }
                    HStack(alignment: .top, spacing: 12) {
                        Field(label: "Expires in", api: "expiresIn", placeholder: "3600s", text: bind("expiresIn"))
                        Select(label: "Purpose", api: "purpose", options: purposes, selection: bind("purpose"))
                    }

                    Lab("Extra fields this flow needs").padding(.top, 4)
                    extra("withDocument", "Document image", "document", "Flows with Face Document Match.") {
                        VStack(alignment: .leading, spacing: 6) {
                            FieldLabel(text: "Document files", api: "document.files")
                            Button(documents.isEmpty ? "Pick document images" : "\(documents.count) file(s) picked") { pickingDocuments = true }
                                .buttonStyle(SecondaryButtonStyle())
                            Hint("Image of the person's document, used by Face Document Match.")
                        }
                        Select(label: "Document purpose", api: "document.purpose", options: documentPurposes, selection: bind("documentPurpose"))
                    }
                    extra("withReferences", "Use case and reference", "useCase, references", "Step-up flows that revalidate an earlier process.") {
                        Select(label: "Use case", api: "useCase", options: useCases, selection: bind("useCase"))
                        Field(label: "Reference process ID", api: "references",
                              hint: reference == nil ? nil : "Filled from your last test. Change it if you want another process.",
                              text: bind("referenceProcessId"))
                    }
                    extra("withContextualization", "Contextualization", "contextualization", "Company, price and reason shown to the person in the journey.") {
                        Field(label: "Company name", api: "company_name", text: bind("companyName"))
                        HStack(alignment: .top, spacing: 12) {
                            Select(label: "Currency", api: "currency", options: currencies, selection: bind("currency"))
                            Field(label: "Price", api: "price", keyboard: .decimalPad, text: bind("price"))
                        }
                        HStack(alignment: .top, spacing: 12) {
                            Select(label: "Reason language", api: "locale", options: locales, selection: bind("locale"))
                            Field(label: "Reason", api: "locale.{language}.reason", text: bind("reason"))
                        }
                    }
                    Hint("Not sure? Leave them off. If the API asks for more, the error names the missing field.")
                }
                .padding(16)
            }
            Dock { Button("Done") { customizing = false }.buttonStyle(PrimaryButtonStyle()) }
        }
        .background(.white)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func failed(_ error: String) -> some View {
        Group {
            VStack(alignment: .leading, spacing: 14) {
                Heading(symbol: "xmark", ink: .badInk, ground: .badGround, title: "Couldn't start the test",
                        subtitle: "\(fields["flow", default: ""]) · process was not created")
                Card {
                    Lab("Response")
                    CodeBlock(error)
                }
                Card {
                    Lab("What you can do").frame(maxWidth: .infinity)
                    Text("Check the information you entered and confirm the flow is active on your account.")
                        .font(.subheadline).foregroundStyle(Color.ink).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                }
            }
            .screen { Button("Try again") { self.error = nil }.buttonStyle(PrimaryButtonStyle()) }
        }
        .background(Color.ground)
    }

    // A switch for a group of extra fields, and the fields themselves while it's on.
    private func extra<Content: View>(
        _ name: String, _ label: String, _ api: String, _ hint: String, @ViewBuilder content: () -> Content
    ) -> some View {
        let on = fields[name] == "true"
        return VStack(alignment: .leading, spacing: 10) {
            Button { fields[name] = String(!on) } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: on ? "checkmark.square.fill" : "square").font(.title3)
                        .foregroundStyle(on ? Color.accent : Color.outline)
                    VStack(alignment: .leading, spacing: 2) {
                        FieldLabel(text: label, api: api)
                        Hint(hint)
                    }
                    .multilineTextAlignment(.leading)
                }
            }
            .buttonStyle(.plain)
            if on { ExtraBox { content() } }
        }
    }

    private func bind(_ name: String) -> Binding<String> {
        Binding { fields[name, default: ""] } set: { fields[name] = $0 }
    }

    private func submit() {
        sending = true
        Task {
            do {
                let files = try documents.map(readBase64)
                error = await onSubmit(buildProcessBody(fields: fields, documentFiles: files, callbackUri: callbackUri))
            } catch {
                self.error = "Could not read a document file: \(error.localizedDescription)"
            }
            sending = false
        }
    }
}

private func readBase64(_ url: URL) throws -> String {
    let access = url.startAccessingSecurityScopedResource()
    defer { if access { url.stopAccessingSecurityScopedResource() } }
    return try Data(contentsOf: url).base64EncodedString()
}
