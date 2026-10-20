// Pure logic behind the create-process form. Foundation only, so it can be tested with `swift test` on a Mac.
// Field names follow https://developer.unico.io/developers/api-reference/post-processes
import Foundation

// `fields` holds the form values as strings; `documentFiles` holds the document files as base64 strings.
// Empty values are dropped, so the API only receives what the user filled in. The flow is whatever the user typed:
// the app doesn't know which flows the account has, so a wrong or disabled one fails on creation.
// `withDocument`, `withReferences` and `withContextualization` are the switches that turn the extra fields on.
func buildProcessBody(fields: [String: String], documentFiles: [String], callbackUri: String) -> [String: Any] {
    func value(_ name: String) -> String? { fields[name].flatMap { $0.isEmpty ? nil : $0 } }
    func on(_ name: String) -> Bool { fields[name] == "true" }

    var body: [String: Any] = [
        "flow": (fields["flow"] ?? "").trimmingCharacters(in: .whitespaces),
        "callbackUri": callbackUri,
    ]

    // Not every flow asks for the person's document. Without its number, the type alone means nothing.
    var person: [String: Any] = [:]
    for key in ["duiValue", "friendlyName", "email", "phone"] { person[key] = value(key) }
    if value("duiValue") != nil { person["duiType"] = value("duiType") }
    if !person.isEmpty { body["person"] = person }

    if on("withDocument"), !documentFiles.isEmpty {
        var document: [String: Any] = ["files": documentFiles.map { ["data": $0] }]
        document["purpose"] = value("documentPurpose")
        body["document"] = document
    }
    if on("withReferences") {
        body["useCase"] = value("useCase")
        if let referenceProcessId = value("referenceProcessId") {
            body["references"] = [["referenceType": "REFERENCE_TYPE_PROCESS_ID", "referenceContent": referenceProcessId]]
        }
    }

    body["expiresIn"] = value("expiresIn")
    body["purpose"] = value("purpose")

    var contextualization: [String: Any] = [:]
    contextualization["company_name"] = value("companyName")
    contextualization["currency"] = value("currency")
    contextualization["price"] = value("price").flatMap(Double.init)
    if let reason = value("reason") {
        contextualization["locale"] = [value("locale") ?? "ptBr": ["reason": reason]]
    }
    if on("withContextualization"), !contextualization.isEmpty { body["contextualization"] = contextualization }
    return body
}
