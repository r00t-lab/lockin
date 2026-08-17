package app.lockin.data

import android.content.Context
import app.lockin.alarm.AlarmService
import app.lockin.model.Commitment
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.serialization.decodeFromString
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.File
import java.util.UUID

/**
 * Single source of truth for commitments. JSON on disk, exposed as a [StateFlow].
 *
 * Do not reach for Room here. There are at most a few dozen records, they are written on
 * user action only, and every hour you spend on a persistence layer is an hour not spent
 * filming. Same reasoning as the iOS side, same file format.
 *
 * Written to be safe from a BroadcastReceiver as well as from Compose: every mutation
 * goes through [mutex] and touches the disk on [Dispatchers.IO].
 */
class CommitmentStore private constructor(context: Context) {

    private val appContext = context.applicationContext
    private val alarms = AlarmService.get(appContext)

    private val file = File(appContext.filesDir, FILENAME)
    private val mutex = Mutex()

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
    }

    private val _commitments = MutableStateFlow(loadFromDisk())
    val commitments: StateFlow<List<Commitment>> = _commitments.asStateFlow()

    // MARK: - Queries

    val activeCount: Int get() = _commitments.value.count { it.isEnabled }

    fun canAddAnother(isPro: Boolean): Boolean = isPro || activeCount < FREE_COMMITMENT_LIMIT

    fun commitment(id: UUID): Commitment? = _commitments.value.firstOrNull { it.id == id }

    /** Everything the stats row and the weekly report need, in one pass. */
    fun stats(): Stats = _commitments.value.fold(Stats(0, 0, 0)) { acc, commitment ->
        Stats(
            proved = acc.proved + if (commitment.isDoneToday) 1 else 0,
            missed = acc.missed + commitment.missCount,
            bestStreak = maxOf(acc.bestStreak, commitment.bestStreak),
        )
    }

    data class Stats(val proved: Int, val missed: Int, val bestStreak: Int)

    // MARK: - Mutations

    suspend fun add(commitment: Commitment) {
        mutate { it + commitment }
        alarms.schedule(commitment)
    }

    suspend fun update(commitment: Commitment) {
        mutate { list -> list.map { if (it.id == commitment.id) commitment else it } }
        alarms.schedule(commitment)
    }

    suspend fun delete(commitment: Commitment) {
        mutate { list -> list.filterNot { it.id == commitment.id } }
        alarms.cancel(commitment.id)
    }

    /**
     * The happy path: user proved they started. Tear down the whole nag chain — proof
     * clears everything, not just the ring that is currently making noise.
     */
    suspend fun recordProof(commitmentId: UUID) {
        val updated = transform(commitmentId) { it.recordingProof() } ?: return
        alarms.clearNags(commitmentId)

        // Recurring commitments need their next occurrence put back on the schedule,
        // because clearNags cancelled the live alarm along with the nag chain.
        if (updated.repeats.isRecurring) alarms.schedule(updated)
    }

    /**
     * User dismissed without proving — from the alarm screen, from the proof screen's
     * "I'm not doing it", or by ignoring the ring until it timed out. Start (or continue)
     * the nag chain.
     */
    suspend fun recordDismissal(commitmentId: UUID) {
        val updated = transform(commitmentId) { it.recordingMiss() } ?: return

        val stillNagging = alarms.scheduleNag(updated)
        if (!stillNagging && updated.repeats.isRecurring) {
            // Out of patience. Put the normal schedule back so tomorrow still happens.
            alarms.schedule(updated)
        }
    }

    /** Called by [BootReceiver][app.lockin.alarm.BootReceiver]. */
    suspend fun rescheduleAll() {
        _commitments.value.filter { it.isEnabled }.forEach { alarms.schedule(it) }
    }

    private suspend fun transform(
        commitmentId: UUID,
        block: (Commitment) -> Commitment,
    ): Commitment? {
        var result: Commitment? = null
        mutate { list ->
            list.map { commitment ->
                if (commitment.id == commitmentId) block(commitment).also { result = it }
                else commitment
            }
        }
        return result
    }

    private suspend fun mutate(block: (List<Commitment>) -> List<Commitment>) = mutex.withLock {
        val next = block(_commitments.value)
        _commitments.value = next
        withContext(Dispatchers.IO) { saveToDisk(next) }
    }

    // MARK: - Persistence

    private fun loadFromDisk(): List<Commitment> = runCatching {
        if (!file.exists()) emptyList() else json.decodeFromString<List<Commitment>>(file.readText())
    }.getOrElse { emptyList() }

    private fun saveToDisk(commitments: List<Commitment>) {
        runCatching {
            // Write-then-rename, so a kill mid-write cannot leave a truncated file that
            // decodes to nothing and silently wipes every commitment the user has.
            val temp = File(file.parentFile, "$FILENAME.tmp")
            temp.writeText(json.encodeToString(commitments))
            if (!temp.renameTo(file)) {
                file.writeText(temp.readText())
                temp.delete()
            }
        }
    }

    companion object {
        private const val FILENAME = "commitments.json"

        /**
         * Free tier ceiling. The paywall exists because of this number — pick it once and
         * do not soften it. Two is enough to feel the mechanic, not enough to live on.
         */
        const val FREE_COMMITMENT_LIMIT = 2

        @Volatile
        private var instance: CommitmentStore? = null

        fun get(context: Context): CommitmentStore =
            instance ?: synchronized(this) {
                instance ?: CommitmentStore(context).also { instance = it }
            }
    }
}
