import Foundation
import Testing
@testable import UnicoReference

private let person = ["flow": "idlive_r2", "duiType": "DUI_TYPE_BR_CPF", "duiValue": "12345678909"]

private func json(_ object: Any) -> String {
    String(decoding: try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
}

private func body(_ extra: [String: String] = [:], files: [String] = []) -> [String: Any] {
    buildProcessBody(fields: person.merging(extra) { $1 }, documentFiles: files, callbackUri: "/")
}

@Test func sendsTheTypedFlowAndOnlyTheFieldsTheUserFilledIn() {
    #expect(json(body(["flow": " idlive_r2 ", "email": "", "purpose": ""]))
        == #"{"callbackUri":"/","flow":"idlive_r2","person":{"duiType":"DUI_TYPE_BR_CPF","duiValue":"12345678909"}}"#)
}

@Test func leavesThePersonOutWhenNoDocumentNumberWasTyped() {
    let body = buildProcessBody(fields: ["flow": "idlive_r2", "duiType": "DUI_TYPE_BR_CPF"], documentFiles: [], callbackUri: "/")

    #expect(json(body) == #"{"callbackUri":"/","flow":"idlive_r2"}"#)
}

@Test func mapsTheNameEmailAndPhoneToThePerson() {
    #expect(json(body(["friendlyName": "Ana", "email": "ana@example.com", "phone": "5511999999999"])["person"]!)
        == #"{"duiType":"DUI_TYPE_BR_CPF","duiValue":"12345678909","email":"ana@example.com","friendlyName":"Ana","phone":"5511999999999"}"#)
}

@Test func addsTheDocumentFilesAndPurposeWhenTheDocumentIsTurnedOn() {
    let body = body(["withDocument": "true", "documentPurpose": "DOCUMENT_PURPOSE_ONBOARDING"], files: ["aGVsbG8="])

    #expect(json(body["document"]!) == #"{"files":[{"data":"aGVsbG8="}],"purpose":"DOCUMENT_PURPOSE_ONBOARDING"}"#)
}

@Test func leavesTheDocumentOutWhenItIsTurnedOffOrHasNoFile() {
    #expect(body(files: ["aGVsbG8="])["document"] == nil)
    #expect(body(["withDocument": "true"])["document"] == nil)
}

@Test func addsUseCaseAndAProcessReferenceWhenTheyAreTurnedOn() {
    let body = body(["withReferences": "true", "useCase": "USE_CASE_LOGIN", "referenceProcessId": "abc-123"])

    #expect(body["useCase"] as? String == "USE_CASE_LOGIN")
    #expect(json(body["references"]!) == #"[{"referenceContent":"abc-123","referenceType":"REFERENCE_TYPE_PROCESS_ID"}]"#)
}

@Test func leavesUseCaseAndReferencesOutWhenTheyAreTurnedOff() {
    #expect(Set(body(["useCase": "USE_CASE_LOGIN", "referenceProcessId": "abc-123"]).keys) == ["flow", "callbackUri", "person"])
}

@Test func mapsExpiresInAndPurpose() {
    let body = body(["expiresIn": "3600s", "purpose": "creditprocess"])

    #expect(body["expiresIn"] as? String == "3600s")
    #expect(body["purpose"] as? String == "creditprocess")
}

@Test func buildsContextualizationWithTheReasonUnderItsLocaleWhenItIsTurnedOn() {
    let body = body([
        "withContextualization": "true", "companyName": "Acme", "currency": "BRL", "price": "10.5",
        "locale": "enUs", "reason": "Purchase",
    ])

    #expect(json(body["contextualization"]!) == #"{"company_name":"Acme","currency":"BRL","locale":{"enUs":{"reason":"Purchase"}},"price":10.5}"#)
}

@Test func leavesContextualizationOutWhenItIsTurnedOff() {
    #expect(body(["companyName": "Acme"])["contextualization"] == nil)
}
