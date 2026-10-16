// Pure logic behind the flows menu and the create-process form. Foundation only, so it can be tested with
// `swift test` on a Mac. Field names follow https://developer.unico.io/developers/api-reference/post-processes
import Foundation

// One row of flows.json, a copy of the root flows.json (CI fails if it drifts).
struct Flow: Decodable, Hashable, Sendable {
    let id: String
    let group: String
    let region: String
    let capabilities: [String]
    let extraFields: [String]
}

func parseFlows(_ json: Data) throws -> [Flow] {
    try JSONDecoder().decode([Flow].self, from: json)
}

func filterFlows(_ flows: [Flow], group: String, region: String) -> [Flow] {
    flows.filter { $0.group == group && (region == "all" || $0.region == region) }
}

// `fields` holds the form values as strings; `documentFiles` holds the document files as base64 strings.
// Empty values are dropped, so the API only receives what the user filled in.
func buildProcessBody(flow: Flow, fields: [String: String], documentFiles: [String], callbackUri: String) -> [String: Any] {
    func value(_ name: String) -> String? { fields[name].flatMap { $0.isEmpty ? nil : $0 } }

    var person: [String: Any] = [:]
    for key in ["duiType", "duiValue", "friendlyName", "email", "phone"] { person[key] = value(key) }
    var body: [String: Any] = ["flow": flow.id, "callbackUri": callbackUri, "person": person]

    if flow.extraFields.contains("document"), !documentFiles.isEmpty {
        var document: [String: Any] = ["files": documentFiles.map { ["data": $0] }]
        document["purpose"] = value("documentPurpose")
        body["document"] = document
    }
    if flow.extraFields.contains("useCase") { body["useCase"] = value("useCase") }
    if flow.extraFields.contains("references"), let referenceProcessId = value("referenceProcessId") {
        body["references"] = [["referenceType": "REFERENCE_TYPE_PROCESS_ID", "referenceContent": referenceProcessId]]
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
    if !contextualization.isEmpty { body["contextualization"] = contextualization }
    return body
}
