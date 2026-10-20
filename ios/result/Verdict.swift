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

// PROCESS_RESULT_OK reads "Success" in green, a definitive negative or an error in red, anything else in grey.
func verdict(_ process: [String: Any]) -> Verdict {
    let result = short(process["result"])
    if result == "OK" { return Verdict(title: "Success", tone: .ok) }
    let tone: Tone = result == "INVALID_IDENTITY" || result == "ERROR" ? .bad : .neutral
    let words = (result ?? short(process["state"]) ?? "").replacingOccurrences(of: "_", with: " ").lowercased()
    return Verdict(title: words.isEmpty ? "Result" : words.prefix(1).uppercased() + words.dropFirst(), tone: tone)
}

// The docs say UTC without the exact format. A timestamp that doesn't parse leaves the duration out.
func durationSeconds(_ process: [String: Any]) -> Int? {
    let format = ISO8601DateFormatter()
    guard let created = (process["createdAt"] as? String).flatMap(format.date(from:)),
          let finished = (process["finishedAt"] as? String).flatMap(format.date(from:)) else { return nil }
    return Int(finished.timeIntervalSince(created))
}
