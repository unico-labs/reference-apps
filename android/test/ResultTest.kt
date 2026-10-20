package io.unico.reference.result

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.jsonObject
import org.junit.Assert.assertEquals
import org.junit.Test

class ResultTest {
    private fun process(text: String) = Json.parseToJsonElement(text).jsonObject

    @Test
    fun `PROCESS_RESULT_OK reads Success in green`() {
        assertEquals(
            Verdict("Success", Tone.OK),
            verdict(process("""{"state":"PROCESS_STATE_FINISHED","result":"PROCESS_RESULT_OK"}""")),
        )
    }

    @Test
    fun `an approval or a successful authentication reads in green, named as the API returns it`() {
        assertEquals(Verdict("Approved", Tone.OK), verdict(process("""{"result":"PROCESS_RESULT_APPROVED"}""")))
        assertEquals(Verdict("Authenticated", Tone.OK), verdict(process("""{"result":"PROCESS_RESULT_AUTHENTICATED"}""")))
    }

    @Test
    fun `a definitive negative or an error reads in red, named as the API returns it`() {
        assertEquals(Verdict("Invalid identity", Tone.BAD), verdict(process("""{"result":"PROCESS_RESULT_INVALID_IDENTITY"}""")))
        assertEquals(Verdict("Error", Tone.BAD), verdict(process("""{"result":"PROCESS_RESULT_ERROR"}""")))
        assertEquals(Verdict("Not approved", Tone.BAD), verdict(process("""{"result":"PROCESS_RESULT_NOT_APPROVED"}""")))
        assertEquals(Verdict("Not live", Tone.BAD), verdict(process("""{"result":"PROCESS_RESULT_NOT_LIVE"}""")))
        assertEquals(Verdict("High risk", Tone.BAD), verdict(process("""{"result":"PROCESS_RESULT_HIGH_RISK"}""")))
        assertEquals(Verdict("Critical risk", Tone.BAD), verdict(process("""{"result":"PROCESS_RESULT_CRITICAL_RISK"}""")))
    }

    @Test
    fun `an authentication with any risk reads in red`() {
        assertEquals(
            Verdict("Authenticated with high risk", Tone.BAD),
            verdict(process("""{"result":"PROCESS_RESULT_AUTHENTICATED_WITH_HIGH_RISK"}""")),
        )
        assertEquals(
            Verdict("Authenticated with critical risk", Tone.BAD),
            verdict(process("""{"result":"PROCESS_RESULT_AUTHENTICATED_WITH_CRITICAL_RISK"}""")),
        )
        assertEquals(
            Verdict("Authenticated with extreme risk", Tone.BAD),
            verdict(process("""{"result":"PROCESS_RESULT_AUTHENTICATED_WITH_EXTREME_RISK"}""")),
        )
    }

    @Test
    fun `any other result reads in grey, and the state stands in when there is no result`() {
        assertEquals(Verdict("Expired", Tone.NEUTRAL), verdict(process("""{"result":"PROCESS_RESULT_EXPIRED"}""")))
        assertEquals(Verdict("Inconclusive", Tone.NEUTRAL), verdict(process("""{"result":"PROCESS_RESULT_INCONCLUSIVE"}""")))
        assertEquals(Verdict("Retry", Tone.NEUTRAL), verdict(process("""{"result":"PROCESS_RESULT_RETRY"}""")))
        assertEquals(Verdict("Created", Tone.NEUTRAL), verdict(process("""{"state":"PROCESS_STATE_CREATED"}""")))
    }

    @Test
    fun `measures how long the journey took from createdAt to finishedAt`() {
        assertEquals(
            38L,
            durationSeconds(process("""{"createdAt":"2026-10-19T12:00:00Z","finishedAt":"2026-10-19T12:00:38Z"}""")),
        )
        assertEquals(null, durationSeconds(process("""{"createdAt":"2026-10-19T12:00:00Z"}""")))
    }

    @Test
    fun `leaves the duration out when a timestamp doesn't parse`() {
        assertEquals(
            null,
            durationSeconds(process("""{"createdAt":"yesterday","finishedAt":"2026-10-19T12:00:38Z"}""")),
        )
    }
}
