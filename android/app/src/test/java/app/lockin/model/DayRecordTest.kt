package app.lockin.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.Instant
import java.time.ZoneId

/**
 * The day record, which is the one thing in this model that is lossy to get wrong.
 *
 * A wrong streak can be recomputed from the days. A day that was never written down, or
 * written twice, cannot be recovered from a counter — so these assertions are about what
 * ends up on disk, not about what the numbers say.
 *
 * Runs on the JVM, no Context — `./gradlew test`.
 */
class DayRecordTest {

    private fun commitment() = Commitment(title = "Write the essay intro", fireAtMillis = 0L)

    private fun millisOn(day: String, hour: Int): Long =
        java.time.LocalDate.parse(day).atTime(hour, 0).atZone(ZoneId.systemDefault())
            .toInstant().toEpochMilli()

    @Test
    fun `proving writes the day down`() {
        val at = millisOn("2026-09-04", 8)
        val after = commitment().recordingProof(at)
        assertEquals(listOf("2026-09-04"), after.provedDays)
    }

    @Test
    fun `proving twice in one day records one day`() {
        // A repeating commitment re-proved after the row is already ticked. The streak
        // guards against this elsewhere; the record has to guard itself, or a single busy
        // Tuesday shows up as a week.
        val morning = millisOn("2026-09-04", 8)
        val evening = millisOn("2026-09-04", 21)
        val after = commitment().recordingProof(morning).recordingProof(evening)
        assertEquals(listOf("2026-09-04"), after.provedDays)
    }

    @Test
    fun `separate days both survive`() {
        val after = commitment()
            .recordingProof(millisOn("2026-09-04", 8))
            .recordingProof(millisOn("2026-09-05", 8))
        assertEquals(listOf("2026-09-04", "2026-09-05"), after.provedDays)
    }

    @Test
    fun `an excuse is written to its own list`() {
        val after = commitment().recordingMiss(millisOn("2026-09-04", 8))
        assertEquals(listOf("2026-09-04"), after.missedDays)
        assertTrue(after.provedDays.isEmpty())
    }

    @Test
    fun `a day can hold both a start and an excuse`() {
        // Two commitments, two outcomes, one day. Neither list may swallow the other:
        // the report colours a square from both, and losing either is a lie in a
        // different direction.
        val day = millisOn("2026-09-04", 8)
        val after = commitment().recordingProof(day).recordingMiss(day)
        assertEquals(listOf("2026-09-04"), after.provedDays)
        assertEquals(listOf("2026-09-04"), after.missedDays)
    }

    @Test
    fun `the stamp is the device's day, not UTC's`() {
        // 00:30 local is the previous day in UTC for anywhere east of Greenwich. Stamping
        // in UTC would file a 12:30am start under yesterday and break the streak the user
        // just earned.
        val at = millisOn("2026-09-04", 0) + 30 * 60 * 1000
        val expected = Instant.ofEpochMilli(at).atZone(ZoneId.systemDefault()).toLocalDate().toString()
        assertEquals(expected, Commitment.dayStamp(at))
        assertEquals("2026-09-04", Commitment.dayStamp(at))
    }
}
