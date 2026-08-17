package app.lockin.alarm

import app.lockin.model.Commitment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZonedDateTime

/**
 * The alarm's recurrence maths is the only pure logic in the app, and it is also the only
 * place a mistake is completely invisible until someone misses a deadline. These run on
 * the JVM with no Android dependencies — `./gradlew test`.
 *
 * Fixed zone and fixed instants on purpose: a test that reads the system clock passes
 * every day except the one where it matters.
 */
class AlarmScheduleTest {

    private val zone = ZoneId.of("Europe/Istanbul")

    private fun at(text: String): java.time.Instant =
        LocalDateTime.parse(text).atZone(zone).toInstant()

    private fun commitment(
        hour: Int,
        minute: Int = 0,
        weekdays: Set<Int> = emptySet(),
    ) = Commitment(
        title = "Write the essay intro",
        // Only hour/minute are read for the recurrence; anchor the date anywhere.
        fireAtMillis = LocalDateTime.of(2026, 1, 1, hour, minute)
            .atZone(zone).toInstant().toEpochMilli(),
        repeats = Commitment.Repeat(weekdays),
    )

    private fun nextAt(commitment: Commitment, now: String): ZonedDateTime =
        java.time.Instant
            .ofEpochMilli(AlarmService.nextTriggerMillis(commitment, at(now), zone))
            .atZone(zone)

    @Test
    fun `one-off later today fires today`() {
        // 2026-08-17 is a Monday.
        val next = nextAt(commitment(hour = 19), now = "2026-08-17T14:00")
        assertEquals(LocalDateTime.parse("2026-08-17T19:00"), next.toLocalDateTime())
    }

    @Test
    fun `one-off already past rolls to tomorrow rather than firing immediately`() {
        val next = nextAt(commitment(hour = 8), now = "2026-08-17T14:00")
        assertEquals(LocalDateTime.parse("2026-08-18T08:00"), next.toLocalDateTime())
    }

    @Test
    fun `recurring picks the next matching weekday`() {
        // Weekdays are 1=Sunday..7=Saturday, so Mon/Wed/Fri is {2, 4, 6}.
        val monWedFri = commitment(hour = 9, weekdays = setOf(2, 4, 6))
        // Monday 14:00 — 09:00 has gone, so Wednesday is next.
        val next = nextAt(monWedFri, now = "2026-08-17T14:00")
        assertEquals(LocalDateTime.parse("2026-08-19T09:00"), next.toLocalDateTime())
    }

    @Test
    fun `recurring still fires today when the time has not passed`() {
        val monWedFri = commitment(hour = 19, weekdays = setOf(2, 4, 6))
        val next = nextAt(monWedFri, now = "2026-08-17T14:00")
        assertEquals(LocalDateTime.parse("2026-08-17T19:00"), next.toLocalDateTime())
    }

    @Test
    fun `recurring wraps across the week boundary`() {
        // Sunday only. From Monday, the answer is six days out.
        val sundayOnly = commitment(hour = 11, weekdays = setOf(1))
        val next = nextAt(sundayOnly, now = "2026-08-17T14:00")
        assertEquals(LocalDateTime.parse("2026-08-23T11:00"), next.toLocalDateTime())
    }

    @Test
    fun `never returns an instant in the past`() {
        val cases = listOf(
            commitment(hour = 0),
            commitment(hour = 23, minute = 59),
            commitment(hour = 7, weekdays = setOf(1, 2, 3, 4, 5, 6, 7)),
        )
        val now = at("2026-08-17T14:00")
        cases.forEach { c ->
            assertTrue(AlarmService.nextTriggerMillis(c, now, zone) > now.toEpochMilli())
        }
    }
}
