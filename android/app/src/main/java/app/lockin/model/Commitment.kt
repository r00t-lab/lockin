package app.lockin.model

import kotlinx.serialization.KSerializer
import kotlinx.serialization.Serializable
import kotlinx.serialization.descriptors.PrimitiveKind
import kotlinx.serialization.descriptors.PrimitiveSerialDescriptor
import kotlinx.serialization.descriptors.SerialDescriptor
import kotlinx.serialization.encoding.Decoder
import kotlinx.serialization.encoding.Encoder
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID

/**
 * A thing the user has committed to starting at a specific time.
 *
 * The whole product is this one noun. Everything else — alarms, proof, streaks —
 * hangs off it. Keep it small; if you are tempted to add a field, add a screen instead.
 *
 * Field-for-field mirror of `Commitment.swift`. The only shape change is [fireAtMillis]
 * standing in for Swift's `Date`, because the two platforms have to agree on a wire
 * format eventually and epoch millis is the cheapest thing both can read.
 */
@Serializable
data class Commitment(
    @Serializable(with = UuidSerializer::class)
    val id: UUID = UUID.randomUUID(),
    /** What the user actually has to start. Shown on the full-screen alarm. */
    val title: String,
    /** Fire time. For recurring commitments only the hour/minute are used. */
    val fireAtMillis: Long,
    val repeats: Repeat = Repeat.NEVER,
    val proofKind: ProofKind = ProofKind.PHOTO,
    /** Null until the user proves they started. Reset each occurrence. */
    val lastCompletedAtMillis: Long? = null,
    val currentStreak: Int = 0,
    val bestStreak: Int = 0,
    /** Occurrences the user dismissed without proving. Feeds the weekly excuse report. */
    val missCount: Int = 0,
    val isEnabled: Boolean = true,
    val createdAtMillis: Long = System.currentTimeMillis(),
) {

    enum class ProofKind {
        /** Photo of the desk / open laptop. Validated on-device, and only on-device. */
        PHOTO,

        /** Start a 25 minute focus timer. Alarm only clears when the timer starts. */
        FOCUS_TIMER,

        /** Scan the QR sticker the user put on their desk. */
        DESK_CODE;

        val label: String
            get() = when (this) {
                PHOTO -> "Photo of your setup"
                FOCUS_TIMER -> "Start a 25-min focus timer"
                DESK_CODE -> "Scan your desk code"
            }

        /** Short form for the commitment row, matching the prototype's meta line. */
        val shortLabel: String
            get() = when (this) {
                PHOTO -> "photo"
                FOCUS_TIMER -> "timer"
                DESK_CODE -> "desk code"
            }
    }

    /**
     * Which days a commitment repeats on. Empty means "once, on [fireAtMillis]".
     *
     * Weekday numbering is 1 = Sunday … 7 = Saturday — the same convention as Swift's
     * `Calendar.component(.weekday:)` and Java's `java.util.Calendar`, deliberately, so
     * a commitment exported from one platform means the same thing on the other.
     * Note this is NOT `java.time.DayOfWeek`, which is ISO (1 = Monday … 7 = Sunday).
     * [Weekdays] does the conversion in one place; never do it inline.
     */
    @Serializable
    data class Repeat(val weekdays: Set<Int> = emptySet()) {

        val isRecurring: Boolean get() = weekdays.isNotEmpty()

        companion object {
            val NEVER = Repeat(emptySet())
            val WEEKDAYS_ONLY = Repeat(setOf(2, 3, 4, 5, 6))
        }
    }

    private val zonedFireTime
        get() = Instant.ofEpochMilli(fireAtMillis).atZone(ZoneId.systemDefault())

    val hour: Int get() = zonedFireTime.hour
    val minute: Int get() = zonedFireTime.minute

    /** True if the user already proved this one today. Used to grey out the row. */
    val isDoneToday: Boolean
        get() {
            val completed = lastCompletedAtMillis ?: return false
            val zone = ZoneId.systemDefault()
            return Instant.ofEpochMilli(completed).atZone(zone).toLocalDate() == LocalDate.now(zone)
        }

    fun recordingProof(atMillis: Long = System.currentTimeMillis()): Commitment {
        val streak = currentStreak + 1
        return copy(
            lastCompletedAtMillis = atMillis,
            currentStreak = streak,
            bestStreak = maxOf(bestStreak, streak),
        )
    }

    fun recordingMiss(): Commitment = copy(currentStreak = 0, missCount = missCount + 1)
}

/** 1 = Sunday … 7 = Saturday, bridging `java.time` to the shared iOS numbering. */
object Weekdays {

    val symbols = listOf("S", "M", "T", "W", "T", "F", "S")

    /** ISO (Mon=1 … Sun=7) → shared (Sun=1 … Sat=7). */
    fun fromLocalDate(date: LocalDate): Int = date.dayOfWeek.value % 7 + 1
}

/**
 * UUIDs are serialised as their canonical string, which is also exactly what the desk
 * QR code contains. Keeping one representation means the scanner can compare payloads
 * with a plain string equality check.
 */
object UuidSerializer : KSerializer<UUID> {
    override val descriptor: SerialDescriptor =
        PrimitiveSerialDescriptor("java.util.UUID", PrimitiveKind.STRING)

    override fun serialize(encoder: Encoder, value: UUID) = encoder.encodeString(value.toString())

    override fun deserialize(decoder: Decoder): UUID = UUID.fromString(decoder.decodeString())
}
