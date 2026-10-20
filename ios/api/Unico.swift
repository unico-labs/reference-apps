// Unico client: JWT, access token, Create Process, Get Process, selfie, evidence set.
// Foundation and Security only (no UIKit or SwiftUI), so it reads the same in any Swift stack, server included.
//
// DEMO ONLY: this app signs the JWT on the device because it has no server. In production this whole file
// runs on your server and the device never holds the service account key. See web/api/unico.js for the same
// client on a server, and https://developer.unico.io/developers/start/authentication ("Never do this on the client side").
import Foundation
import Security

// https://developer.unico.io/developers/start/environments
struct Hosts: Equatable, Sendable {
    let identity: String
    let api: String

    static let uat = Hosts(identity: "https://identityhomolog.acesso.io", api: "https://api.idcloud.uat.unico.app")
    static let prod = Hosts(identity: "https://identity.acesso.io", api: "https://api.idcloud.unico.app")
}

// Any non-2xx answer from Unico, with the status and body exactly as returned.
struct UnicoError: Error {
    let status: Int
    let body: String
}

// Bad input caught here, before anything is sent to Unico.
struct InvalidInputError: Error {
    let message: String
}

// The docs ask for proactive renewal when 10 minutes or less remain.
private let renewBefore: TimeInterval = 10 * 60

// Judgment call: long enough for a slow mobile network, short enough that a dead connection surfaces as an error.
private let timeout: TimeInterval = 30

// Ids are interpolated into the URL, so anything like `../` is refused before calling Unico.
private func processId(_ id: String) throws -> String {
    guard id.wholeMatch(of: /[\w-]+/) != nil else { throw InvalidInputError(message: "invalid process id") }
    return id
}

// An actor, so the cached token is read and written from one place at a time.
actor Unico {
    private let serviceAccount: String
    private let privateKey: SecKey
    private let hosts: Hosts
    private let session: URLSession
    private var accessToken: String?
    private var renewAt = Date.distantPast
    private var pending: Task<String, Error>?

    init(serviceAccount: String, privateKey: SecKey, hosts: Hosts, session: URLSession = .shared) {
        self.serviceAccount = serviceAccount
        self.privateKey = privateKey
        self.hosts = hosts
        self.session = session
    }

    // https://developer.unico.io/developers/start/authentication
    // DEMO ONLY: signs with the service account key held on the device. Don't carry this into an app.
    private func signAssertion() throws -> String {
        let now = Int(Date().timeIntervalSince1970)
        let header: [String: Any] = ["alg": "RS256", "typ": "JWT"]
        // Only these claims: any other (sub, jti, nbf) is refused with error 1.2.22.
        let payload: [String: Any] = ["iss": serviceAccount, "aud": hosts.identity, "scope": "*", "iat": now, "exp": now + 3600]
        let signingInput = try base64URL(json(header)) + "." + base64URL(json(payload))
        var error: Unmanaged<CFError>?
        // RS256 is RSASSA-PKCS1-v1_5 with SHA-256.
        guard let signature = SecKeyCreateSignature(
            privateKey, .rsaSignatureMessagePKCS1v15SHA256, Data(signingInput.utf8) as CFData, &error
        ) else { throw error!.takeRetainedValue() }
        return signingInput + "." + base64URL(signature as Data)
    }

    private func requestToken() async throws -> String {
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "grant_type", value: "urn:ietf:params:oauth:grant-type:jwt-bearer"),
            URLQueryItem(name: "assertion", value: try signAssertion()),
        ]
        let (status, data) = try await send(
            "POST", "\(hosts.identity)/oauth2/token", bearer: nil,
            contentType: "application/x-www-form-urlencoded", body: Data(form.percentEncodedQuery!.utf8)
        )
        let text = String(decoding: data, as: UTF8.self)
        guard (200...299).contains(status) else { throw UnicoError(status: status, body: text) }

        let json = try parse(status, data)
        guard let token = json["access_token"] as? String, let expiresIn = json["expires_in"] as? Double else {
            throw UnicoError(status: status, body: text)
        }
        accessToken = token
        renewAt = Date().addingTimeInterval(expiresIn - renewBefore)
        return token
    }

    // Concurrent callers share one request. Two assertions signed in the same second are identical,
    // and Unico refuses a reused JWT (error 1.2.7). Public so an app can check its credentials on their own:
    // a token proves the account, tenant and key are right, but says nothing about which flows the account has.
    func accessToken() async throws -> String {
        if let accessToken, Date() < renewAt { return accessToken }
        if let pending { return try await pending.value }
        let request = Task { try await requestToken() }
        pending = request
        defer { pending = nil }
        return try await request.value
    }

    private func call(_ method: String, _ path: String, body: sending [String: Any]? = nil) async throws -> sending [String: Any] {
        let (status, data) = try await send(
            method, "\(hosts.api)\(path)", bearer: try await accessToken(),
            contentType: "application/json", body: try body.map { try JSONSerialization.data(withJSONObject: $0) }
        )
        guard (200...299).contains(status) else { throw UnicoError(status: status, body: String(decoding: data, as: UTF8.self)) }
        return try parse(status, data)
    }

    // https://developer.unico.io/developers/api-reference/post-processes → { process }
    func createProcess(_ body: sending [String: Any]) async throws -> sending [String: Any] {
        try await call("POST", "/client/v1/process", body: body)
    }

    // https://developer.unico.io/developers/api-reference/get-process → { process }
    func getProcess(_ id: String) async throws -> sending [String: Any] {
        try await call("GET", "/client/v1/process/\(processId(id))")
    }

    // https://developer.unico.io/developers/api-reference/get-selfie → { fileContents, contentType }
    func getSelfie(_ id: String) async throws -> sending [String: Any] {
        try await call("GET", "/client/v1/process/\(processId(id))/selfie")
    }

    // https://developer.unico.io/developers/api-reference/get-evidence-set → { fileContents, contentType }
    // contentType comes back as "x-pdf"; fileContents is a base64 PDF.
    func getEvidenceSet(_ id: String) async throws -> sending [String: Any] {
        try await call("GET", "/client/v1/process/\(processId(id))/evidenceset")
    }

    // Plain URLSession: one request, status and body back. Network failures throw URLError.
    private func send(
        _ method: String, _ url: String, bearer: String?, contentType: String, body: Data?
    ) async throws -> (Int, Data) {
        guard let url = URL(string: url) else { throw InvalidInputError(message: "invalid host: \(url)") }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        return ((response as! HTTPURLResponse).statusCode, data)
    }
}

// A 2xx answer that isn't a JSON object is still Unico's answer, so it surfaces as a UnicoError with the body as sent.
private func parse(_ status: Int, _ data: Data) throws -> [String: Any] {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw UnicoError(status: status, body: String(decoding: data, as: UTF8.self))
    }
    return json
}

private func json(_ object: [String: Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: object, options: .withoutEscapingSlashes)
}

private func base64URL(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}
