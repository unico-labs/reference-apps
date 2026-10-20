// The heading of the result screen. It only names the result the API returned, in words:
// https://developer.unico.io/developers/api-reference/get-process. The JSON on screen stays as returned.
import Foundation

enum Tone: Equatable, Sendable { case ok, bad, neutral }

struct Verdict: Equatable, Sendable {
    let title: String
    let tone: Tone
}

func short(_ value: Any?) -> String? {
    (value as? String)?.replacingOccurrences(of: "PROCESS_RESULT_", with: "").replacingOccurrences(of: "PROCESS_STATE_", with: "")
}

// Result values per flow: https://developer.unico.io/developers/start/flows
private let okResults: Set = ["PROCESS_RESULT_OK", "PROCESS_RESULT_APPROVED", "PROCESS_RESULT_AUTHENTICATED"]
private let badResults: Set = [
    "PROCESS_RESULT_INVALID_IDENTITY", "PROCESS_RESULT_ERROR", "PROCESS_RESULT_NOT_APPROVED", "PROCESS_RESULT_NOT_LIVE",
    "PROCESS_RESULT_HIGH_RISK", "PROCESS_RESULT_CRITICAL_RISK", "PROCESS_RESULT_AUTHENTICATED_WITH_HIGH_RISK",
    "PROCESS_RESULT_AUTHENTICATED_WITH_CRITICAL_RISK", "PROCESS_RESULT_AUTHENTICATED_WITH_EXTREME_RISK",
]

// PROCESS_RESULT_OK reads "Success"; an approval reads green, a negative, a risk or an error red, anything else grey.
func verdict(_ process: [String: Any]) -> Verdict {
    let raw = process["result"] as? String
    let result = short(raw)
    if result == "OK" { return Verdict(title: "Success", tone: .ok) }
    let tone: Tone = raw.map { okResults.contains($0) ? .ok : badResults.contains($0) ? .bad : .neutral } ?? .neutral
    let words = (result ?? short(process["state"]) ?? "").replacingOccurrences(of: "_", with: " ").lowercased()
    return Verdict(title: words.isEmpty ? "Result" : words.prefix(1).uppercased() + words.dropFirst(), tone: tone)
}

// Unico's timestamps carry fractional seconds (2026-08-06T01:42:21.693615Z), which the default formatter rejects.
// A timestamp that doesn't parse either way leaves the duration out.
func durationSeconds(_ process: [String: Any]) -> Int? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    let plain = ISO8601DateFormatter()
    func date(_ key: String) -> Date? {
        (process[key] as? String).flatMap { fractional.date(from: $0) ?? plain.date(from: $0) }
    }
    guard let created = date("createdAt"), let finished = date("finishedAt") else { return nil }
    return Int(finished.timeIntervalSince(created))
}
