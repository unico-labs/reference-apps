import Foundation
import Security
import Testing
@testable import UnicoReference

// A local fake of the Unico endpoints, plugged into URLSession with a URLProtocol. Each test gets its own host,
// so tests running in parallel never see each other's requests.
private final class FakeUnico: @unchecked Sendable {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var fakes: [String: FakeUnico] = [:]

    let host = "fake-\(UUID().uuidString.lowercased()).test"
    var tokenStatus = 200
    private(set) var tokenRequests: [[String: String]] = []
    private(set) var apiRequests: [[String]] = []

    init() { Self.lock.withLock { Self.fakes[host] = self } }

    static func answer(_ request: URLRequest) -> (Int, String) {
        let fake = lock.withLock { fakes[request.url!.host()!]! }
        return lock.withLock { fake.answer(request) }
    }

    func recorded<T>(_ read: (FakeUnico) -> T) -> T { Self.lock.withLock { read(self) } }

    private func answer(_ request: URLRequest) -> (Int, String) {
        let body = request.httpBodyStream.map(readAll) ?? ""
        let path = request.url!.path()
        if path == "/oauth2/token" {
            var form = URLComponents()
            form.percentEncodedQuery = body
            tokenRequests.append(Dictionary(uniqueKeysWithValues: form.queryItems!.map { ($0.name, $0.value ?? "") }))
            if tokenStatus != 200 { return (tokenStatus, #"{"error":"server_error","error_description":"1.2.21: wrong private key"}"#) }
            return (200, #"{"access_token":"token-\#(tokenRequests.count)","token_type":"Bearer","expires_in":3600}"#)
        }
        let method = request.httpMethod!
        apiRequests.append([method, path, request.value(forHTTPHeaderField: "Authorization") ?? "", body])
        switch "\(method) \(path)" {
        case "POST /client/v1/process": return (200, #"{"process":{"id":"abc-123","webAppToken":"web-app-token"}}"#)
        case "GET /client/v1/process/abc-123": return (200, #"{"process":{"id":"abc-123","state":"PROCESS_STATE_FINISHED"}}"#)
        case "GET /client/v1/process/abc-123/selfie": return (200, #"{"fileContents":"/9j/4AAQ","contentType":"image/jpeg"}"#)
        case "GET /client/v1/process/abc-123/evidenceset": return (200, #"{"fileContents":"JVBERi0xLjMN","contentType":"x-pdf"}"#)
        case "GET /client/v1/process/behind-gateway": return (502, "<html>Bad Gateway</html>")
        default: return (404, #"{"code":5,"message":"error getting process: rpc error: code = NotFound desc = process not found"}"#)
        }
    }
}

private func readAll(_ stream: InputStream) -> String {
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while case let count = stream.read(&buffer, maxLength: buffer.count), count > 0 { data.append(buffer, count: count) }
    return String(decoding: data, as: UTF8.self)
}

private final class FakeUnicoProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        let (status, body) = FakeUnico.answer(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }
}

nonisolated(unsafe) private let keys: (private: SecKey, public: SecKey) = {
    let key = SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048] as CFDictionary, nil)!
    return (key, SecKeyCopyPublicKey(key)!)
}()

private func unico(_ fake: FakeUnico) -> Unico {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [FakeUnicoProtocol.self]
    let base = "https://\(fake.host)"
    return Unico(
        serviceAccount: "my-account@abc123.iam.acesso.io",
        privateKey: keys.private,
        hosts: Hosts(identity: base, api: base),
        session: URLSession(configuration: configuration)
    )
}

private func decode(_ part: Substring) -> [String: Any] {
    try! JSONSerialization.jsonObject(with: base64URLDecode(part)) as! [String: Any]
}

private func base64URLDecode(_ part: Substring) -> Data {
    var base64 = part.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
    return Data(base64Encoded: base64)!
}

@Test func exchangesASignedRS256JWTForAnAccessToken() async throws {
    let fake = FakeUnico()
    _ = try await unico(fake).getProcess("abc-123")

    let params = fake.recorded { $0.tokenRequests }.first!
    #expect(params["grant_type"] == "urn:ietf:params:oauth:grant-type:jwt-bearer")
    let parts = params["assertion"]!.split(separator: ".")
    #expect(decode(parts[0])["alg"] as? String == "RS256")
    let claims = decode(parts[1])
    #expect(Set(claims.keys) == ["iss", "aud", "scope", "iat", "exp"])
    #expect(claims["iss"] as? String == "my-account@abc123.iam.acesso.io")
    #expect(claims["aud"] as? String == "https://\(fake.host)")
    #expect(claims["scope"] as? String == "*")
    #expect((claims["exp"] as! Int) - (claims["iat"] as! Int) == 3600)
    let verified = SecKeyVerifySignature(
        keys.public, .rsaSignatureMessagePKCS1v15SHA256,
        Data("\(parts[0]).\(parts[1])".utf8) as CFData, base64URLDecode(parts[2]) as CFData, nil
    )
    #expect(verified)
}

@Test func createsAProcessWithTheBearerTokenAndReturnsTheBodyAsSent() async throws {
    let fake = FakeUnico()

    let result = try await unico(fake).createProcess(["flow": "idlive_r2", "callbackUri": "/"])

    #expect((result["process"] as? [String: Any])?["webAppToken"] as? String == "web-app-token")
    let request = fake.recorded { $0.apiRequests }.first!
    #expect(request[0...2] == ["POST", "/client/v1/process", "Bearer token-1"])
    let sent = try JSONSerialization.jsonObject(with: Data(request[3].utf8)) as! [String: String]
    #expect(sent == ["flow": "idlive_r2", "callbackUri": "/"])
}

@Test func concurrentCallsShareOneTokenRequestAndLaterCallsReuseIt() async throws {
    let fake = FakeUnico()
    let client = unico(fake)

    async let process = client.getProcess("abc-123")
    async let selfie = client.getSelfie("abc-123")
    _ = try await (process, selfie)
    _ = try await client.getEvidenceSet("abc-123")

    #expect(fake.recorded { $0.tokenRequests.count } == 1)
    #expect(fake.recorded { $0.apiRequests.map { $0[1] } }.sorted() == [
        "/client/v1/process/abc-123", "/client/v1/process/abc-123/evidenceset", "/client/v1/process/abc-123/selfie",
    ])
}

@Test func anAPIErrorCarriesTheStatusAndBodyAsReturned() async {
    let error = await #expect(throws: UnicoError.self) { try await unico(FakeUnico()).getProcess("missing") }

    #expect(error?.status == 404)
    #expect(error?.body == #"{"code":5,"message":"error getting process: rpc error: code = NotFound desc = process not found"}"#)
}

@Test func aNonJSONErrorBodyComesBackAsText() async {
    let error = await #expect(throws: UnicoError.self) { try await unico(FakeUnico()).getProcess("behind-gateway") }

    #expect(error?.status == 502)
    #expect(error?.body == "<html>Bad Gateway</html>")
}

@Test func aTokenErrorStopsBeforeTheAPICall() async {
    let fake = FakeUnico()
    fake.tokenStatus = 401

    let error = await #expect(throws: UnicoError.self) { try await unico(fake).getProcess("abc-123") }

    #expect(error?.status == 401)
    #expect(error?.body.contains("1.2.21") == true)
    #expect(fake.recorded { $0.apiRequests.isEmpty })
}

@Test func verifyingTheConnectionRequestsATokenAndCallsNothingElse() async throws {
    let fake = FakeUnico()

    _ = try await unico(fake).accessToken()

    #expect(fake.recorded { $0.tokenRequests.count } == 1)
    #expect(fake.recorded { $0.apiRequests.isEmpty })
}

@Test func verifyingWithAWrongKeyFailsWithTheTokenErrorAsReturned() async {
    let fake = FakeUnico()
    fake.tokenStatus = 401

    let error = await #expect(throws: UnicoError.self) { try await unico(fake).accessToken() }

    #expect(error?.status == 401)
    #expect(error?.body.contains("1.2.21") == true)
}

@Test func aMalformedProcessIdIsRefusedBeforeAnythingIsSent() async {
    let fake = FakeUnico()

    await #expect(throws: InvalidInputError.self) { try await unico(fake).getSelfie("../token") }

    #expect(fake.recorded { $0.tokenRequests.isEmpty && $0.apiRequests.isEmpty })
}

@Test func aNetworkFailureSurfacesAsAURLError() async {
    let nothingListening = Hosts(identity: "http://127.0.0.1:1", api: "http://127.0.0.1:1")
    let client = Unico(serviceAccount: "my-account@abc123.iam.acesso.io", privateKey: keys.private, hosts: nothingListening)

    await #expect(throws: URLError.self) { try await client.getProcess("abc-123") }
}

@Test func readsAPKCS8PemAndRefusesOtherFormats() throws {
    let pkcs1 = SecKeyCopyExternalRepresentation(keys.private, nil)! as Data
    let rsaAlgorithm: [UInt8] = [0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00]
    func der(_ tag: UInt8, _ content: [UInt8]) -> [UInt8] {
        [tag, 0x82, UInt8(content.count >> 8), UInt8(content.count & 0xff)] + content
    }
    let pkcs8 = der(0x30, [0x02, 0x01, 0x00] + rsaAlgorithm + der(0x04, [UInt8](pkcs1)))
    let pem = "-----BEGIN PRIVATE KEY-----\n\(Data(pkcs8).base64EncodedString(options: .lineLength64Characters))\n-----END PRIVATE KEY-----\n"

    let parsed = try parsePrivateKey(pem)

    #expect(SecKeyCopyExternalRepresentation(parsed, nil)! as Data == pkcs1)
    #expect(throws: SettingsError.self) { try parsePrivateKey(pem.replacingOccurrences(of: "PRIVATE KEY", with: "RSA PRIVATE KEY")) }
    #expect(throws: SettingsError.self) { try parsePrivateKey("not a key") }
}
