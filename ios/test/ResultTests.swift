import Testing
@testable import UnicoReference

@Test func processResultOKReadsSuccessInGreen() {
    #expect(verdict(["state": "PROCESS_STATE_FINISHED", "result": "PROCESS_RESULT_OK"]) == Verdict(title: "Success", tone: .ok))
}

@Test func anApprovalOrAnAuthenticationReadsInGreenNamedAsTheAPIReturnsIt() {
    #expect(verdict(["result": "PROCESS_RESULT_APPROVED"]) == Verdict(title: "Approved", tone: .ok))
    #expect(verdict(["result": "PROCESS_RESULT_AUTHENTICATED"]) == Verdict(title: "Authenticated", tone: .ok))
}

@Test func aDefinitiveNegativeARiskOrAnErrorReadsInRedNamedAsTheAPIReturnsIt() {
    #expect(verdict(["result": "PROCESS_RESULT_INVALID_IDENTITY"]) == Verdict(title: "Invalid identity", tone: .bad))
    #expect(verdict(["result": "PROCESS_RESULT_ERROR"]) == Verdict(title: "Error", tone: .bad))
    #expect(verdict(["result": "PROCESS_RESULT_NOT_APPROVED"]) == Verdict(title: "Not approved", tone: .bad))
    #expect(verdict(["result": "PROCESS_RESULT_NOT_LIVE"]) == Verdict(title: "Not live", tone: .bad))
    #expect(verdict(["result": "PROCESS_RESULT_HIGH_RISK"]) == Verdict(title: "High risk", tone: .bad))
    #expect(verdict(["result": "PROCESS_RESULT_CRITICAL_RISK"]) == Verdict(title: "Critical risk", tone: .bad))
    #expect(verdict(["result": "PROCESS_RESULT_AUTHENTICATED_WITH_HIGH_RISK"]) == Verdict(title: "Authenticated with high risk", tone: .bad))
    #expect(verdict(["result": "PROCESS_RESULT_AUTHENTICATED_WITH_CRITICAL_RISK"]) == Verdict(title: "Authenticated with critical risk", tone: .bad))
    #expect(verdict(["result": "PROCESS_RESULT_AUTHENTICATED_WITH_EXTREME_RISK"]) == Verdict(title: "Authenticated with extreme risk", tone: .bad))
}

@Test func anyOtherResultReadsInGreyAndTheStateStandsInWhenThereIsNoResult() {
    #expect(verdict(["result": "PROCESS_RESULT_EXPIRED"]) == Verdict(title: "Expired", tone: .neutral))
    #expect(verdict(["result": "PROCESS_RESULT_INCONCLUSIVE"]) == Verdict(title: "Inconclusive", tone: .neutral))
    #expect(verdict(["result": "PROCESS_RESULT_RETRY"]) == Verdict(title: "Retry", tone: .neutral))
    #expect(verdict(["state": "PROCESS_STATE_CREATED"]) == Verdict(title: "Created", tone: .neutral))
}

@Test func measuresHowLongTheJourneyTookFromCreatedAtToFinishedAt() {
    #expect(durationSeconds(["createdAt": "2026-10-19T12:00:00Z", "finishedAt": "2026-10-19T12:00:38Z"]) == 38)
    #expect(durationSeconds(["createdAt": "2026-10-19T12:00:00Z"]) == nil)
}

@Test func readsTimestampsWithFractionalSeconds() {
    #expect(durationSeconds(["createdAt": "2026-08-06T01:42:21.693615Z", "finishedAt": "2026-08-06T01:43:00.120Z"]) == 38)
}

@Test func leavesTheDurationOutWhenATimestampDoesntParse() {
    #expect(durationSeconds(["createdAt": "yesterday", "finishedAt": "2026-10-19T12:00:38Z"]) == nil)
}
