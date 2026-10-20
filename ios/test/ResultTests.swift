import Testing
@testable import UnicoReference

@Test func processResultOKReadsSuccessInGreen() {
    #expect(verdict(["state": "PROCESS_STATE_FINISHED", "result": "PROCESS_RESULT_OK"]) == Verdict(title: "Success", tone: .ok))
}

@Test func aDefinitiveNegativeOrAnErrorReadsInRedNamedAsTheAPIReturnsIt() {
    #expect(verdict(["result": "PROCESS_RESULT_INVALID_IDENTITY"]) == Verdict(title: "Invalid identity", tone: .bad))
    #expect(verdict(["result": "PROCESS_RESULT_ERROR"]) == Verdict(title: "Error", tone: .bad))
}

@Test func anyOtherResultReadsInGreyAndTheStateStandsInWhenThereIsNoResult() {
    #expect(verdict(["result": "PROCESS_RESULT_EXPIRED"]) == Verdict(title: "Expired", tone: .neutral))
    #expect(verdict(["state": "PROCESS_STATE_CREATED"]) == Verdict(title: "Created", tone: .neutral))
}

@Test func measuresHowLongTheJourneyTookFromCreatedAtToFinishedAt() {
    #expect(durationSeconds(["createdAt": "2026-10-19T12:00:00Z", "finishedAt": "2026-10-19T12:00:38Z"]) == 38)
    #expect(durationSeconds(["createdAt": "2026-10-19T12:00:00Z"]) == nil)
}

@Test func leavesTheDurationOutWhenATimestampDoesntParse() {
    #expect(durationSeconds(["createdAt": "yesterday", "finishedAt": "2026-10-19T12:00:38Z"]) == nil)
}
