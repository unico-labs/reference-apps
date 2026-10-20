// DEMO ONLY: credentials typed into the device. In production the service account key lives only on your server,
// which creates the process and hands the app nothing but the webAppToken. Don't carry this file into an app.
//
// What it does, for the demo: one environment (UAT hosts prefilled, editable), the service account, the SDK key,
// and the .pem key in the Keychain with kSecAttrAccessibleWhenUnlockedThisDeviceOnly: readable only while the
// device is unlocked, and left out of backups and device migration, so the key never leaves this device.
import Foundation
import Security

struct Settings: Hashable, CustomStringConvertible {
    var identityHost = Hosts.uat.identity
    var apiHost = Hosts.uat.api
    var account = ""
    var tenant = ""
    // Issued by Unico's Onboarding team for this build's Bundle Identifier:
    // https://developer.unico.io/developers/sdks-and-tools/ios/installation/specific-setup
    var sdkKey = ""
    var privateKeyPem = ""

    var hosts: Hosts { Hosts(identity: trimSlash(identityHost), api: trimSlash(apiHost)) }

    // The `iss` claim: https://developer.unico.io/developers/start/authentication
    var serviceAccount: String { "\(account)@\(tenant).iam.acesso.io" }

    // What step 1 of setup asks for: enough to request a token.
    var hasCredentials: Bool {
        [identityHost, apiHost, account, tenant, privateKeyPem].allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var isComplete: Bool { hasCredentials && !sdkKey.trimmingCharacters(in: .whitespaces).isEmpty }

    // Keeps the key out of logs and crash reports.
    var description: String { "Settings(identityHost: \(identityHost), apiHost: \(apiHost), account: \(account), tenant: \(tenant))" }
}

private func trimSlash(_ host: String) -> String {
    host.hasSuffix("/") ? String(host.dropLast()) : host
}

struct SettingsError: LocalizedError {
    let errorDescription: String?
}

// A key copied from an email often loses its PEM header or arrives in another format. Check it on Verify
// credentials, so the error names what was found instead of failing on the first token request.
func parsePrivateKey(_ pem: String) throws -> SecKey {
    let header = pem.firstMatch(of: /-----BEGIN ([A-Z ]+)-----/)?.1
    guard header == "PRIVATE KEY" else {
        let found = header.map { "found: \($0)" } ?? "no PEM header"
        throw SettingsError(errorDescription: "Not a PEM private key (\(found)). It should start with -----BEGIN PRIVATE KEY-----.")
    }
    let base64 = pem.firstMatch(of: /-----BEGIN PRIVATE KEY-----([^-]*)-----END PRIVATE KEY-----/)?.1.filter { !$0.isWhitespace } ?? ""
    // Security.framework takes an RSA key as PKCS#1, and Unico's .pem is PKCS#8, so the PKCS#1 key is unwrapped first.
    guard let der = Data(base64Encoded: base64), let pkcs1 = pkcs1(fromPKCS8: [UInt8](der)) else {
        throw SettingsError(errorDescription: "The PEM body is not a PKCS#8 private key.")
    }
    let attributes: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPrivate]
    guard let key = SecKeyCreateWithData(Data(pkcs1) as CFData, attributes as CFDictionary, nil) else {
        throw SettingsError(errorDescription: "Not a valid RSA private key.")
    }
    return key
}

// PKCS#8 is SEQUENCE { INTEGER version, SEQUENCE algorithm, OCTET STRING privateKey }, and for RSA
// the OCTET STRING holds the PKCS#1 key. Reads just enough DER to return those bytes.
private func pkcs1(fromPKCS8 der: [UInt8]) -> [UInt8]? {
    var index = 0
    func element(_ tag: UInt8) -> Int? {
        guard index + 1 < der.count, der[index] == tag else { return nil }
        var length = Int(der[index + 1])
        index += 2
        if length & 0x80 != 0 {
            let bytes = length & 0x7f
            guard bytes <= 4, index + bytes <= der.count else { return nil }
            length = der[index..<index + bytes].reduce(0) { $0 << 8 | Int($1) }
            index += bytes
        }
        return index + length <= der.count ? length : nil
    }
    guard element(0x30) != nil, let version = element(0x02) else { return nil }
    index += version
    guard let algorithm = element(0x30) else { return nil }
    index += algorithm
    guard let key = element(0x04) else { return nil }
    return Array(der[index..<index + key])
}

struct SettingsStore {
    private let defaults = UserDefaults.standard
    private let keychainItem: [CFString: Any] = [
        kSecClass: kSecClassGenericPassword,
        kSecAttrService: "unico-reference",
        kSecAttrAccount: "service-account-pem",
    ]

    func load() -> Settings {
        var settings = Settings()
        settings.identityHost = defaults.string(forKey: "identityHost") ?? Hosts.uat.identity
        settings.apiHost = defaults.string(forKey: "apiHost") ?? Hosts.uat.api
        settings.account = defaults.string(forKey: "account") ?? ""
        settings.tenant = defaults.string(forKey: "tenant") ?? ""
        settings.sdkKey = defaults.string(forKey: "sdkKey") ?? ""
        settings.privateKeyPem = readKey() ?? ""
        return settings
    }

    // The key goes first, so a Keychain failure leaves the saved account untouched.
    func save(_ settings: Settings) throws {
        // Incomplete settings would open Run a flow with no Unico client behind it.
        guard settings.isComplete else { throw SettingsError(errorDescription: "Fill in the API credentials and the SDK key.") }
        SecItemDelete(keychainItem as CFDictionary)
        var item = keychainItem
        item[kSecValueData] = Data(settings.privateKeyPem.utf8)
        item[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let status = SecItemAdd(item as CFDictionary, nil)
        guard status == errSecSuccess else { throw SettingsError(errorDescription: "Could not save the key in the Keychain (OSStatus \(status)).") }
        defaults.set(settings.identityHost, forKey: "identityHost")
        defaults.set(settings.apiHost, forKey: "apiHost")
        defaults.set(settings.account, forKey: "account")
        defaults.set(settings.tenant, forKey: "tenant")
        defaults.set(settings.sdkKey, forKey: "sdkKey")
    }

    private func readKey() -> String? {
        var query = keychainItem
        query[kSecReturnData] = true
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
