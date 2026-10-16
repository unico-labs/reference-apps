import Foundation
import Testing
@testable import UnicoReference

private let flows = try! parseFlows(Data(contentsOf: URL(filePath: #filePath).deletingLastPathComponent().appending(path: "../flows/flows.json")))
private func flow(_ id: String) -> Flow { flows.first { $0.id == id }! }

private func json(_ object: Any) -> String {
    String(decoding: try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
}

@Test func filtersByGroupAndRegion() {
    #expect(filterFlows(flows, group: "step-up", region: "all").map(\.id) == ["idsmart_r2", "idsmart_tp1"])
    #expect(filterFlows(flows, group: "sign-up", region: "mexico").map(\.id) == ["idtrust_r2-idgov", "idtrustdocs_r2-idgov"])
}

@Test func sendsOnlyTheFieldsTheUserFilledIn() {
    let body = buildProcessBody(
        flow: flow("idlive_r2"),
        fields: ["duiType": "DUI_TYPE_BR_CPF", "duiValue": "12345678909", "email": "", "purpose": ""],
        documentFiles: [],
        callbackUri: "/"
    )

    #expect(json(body) == #"{"callbackUri":"/","flow":"idlive_r2","person":{"duiType":"DUI_TYPE_BR_CPF","duiValue":"12345678909"}}"#)
}

@Test func addsUseCaseAndReferencesForSmartRevalidation() {
    let body = buildProcessBody(
        flow: flow("idsmart_r2"),
        fields: ["useCase": "USE_CASE_LOGIN", "referenceProcessId": "abc-123"],
        documentFiles: [],
        callbackUri: "/"
    )

    #expect(body["useCase"] as? String == "USE_CASE_LOGIN")
    #expect(json(body["references"]!) == #"[{"referenceContent":"abc-123","referenceType":"REFERENCE_TYPE_PROCESS_ID"}]"#)
}

@Test func addsDocumentFilesOnlyForFlowsWithFaceDocumentMatch() {
    let fields = ["documentPurpose": "DOCUMENT_PURPOSE_ONBOARDING"]

    let withDocs = buildProcessBody(flow: flow("idunicodocs_r2"), fields: fields, documentFiles: ["aGVsbG8="], callbackUri: "/")
    let withoutDocs = buildProcessBody(flow: flow("idlive_r2"), fields: fields, documentFiles: ["aGVsbG8="], callbackUri: "/")

    #expect(json(withDocs["document"]!) == #"{"files":[{"data":"aGVsbG8="}],"purpose":"DOCUMENT_PURPOSE_ONBOARDING"}"#)
    #expect(withoutDocs["document"] == nil)
}

@Test func buildsContextualizationWithTheReasonUnderItsLocale() {
    let body = buildProcessBody(
        flow: flow("idlive_r2"),
        fields: ["companyName": "Acme", "currency": "BRL", "price": "10.5", "locale": "enUs", "reason": "Purchase"],
        documentFiles: [],
        callbackUri: "/"
    )

    #expect(json(body["contextualization"]!) == #"{"company_name":"Acme","currency":"BRL","locale":{"enUs":{"reason":"Purchase"}},"price":10.5}"#)
}
