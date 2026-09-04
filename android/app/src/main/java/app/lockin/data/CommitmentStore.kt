package app.lockin.data

import android.content.Context
import app.lockin.alarm.AlarmService
import app.lockin.billing.SellState
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

    /**
     * Everything the user actually committed to. The rehearsal lives in the same list so
     * it rings through the same machinery, but it must never appear in a count: counting
     * it would push someone into the paywall for pressing a demo button, and it would
     * inflate the streak the whole product exists to keep honest.
     */
    val real: List<Commitment> get() = _commitments.value.filterNot { it.isRehearsal }

    val rehearsal: Commitment? get() = _commitments.value.firstOrNull { it.isRehearsal }

    val activeCount: Int get() = real.count { it.isEnabled }

    /** This store's commitments, run through [mayAddAnother]. */
    fun canAddAnother(isPro: Boolean, sellState: SellState): Boolean =
        mayAddAnother(activeCount, isPro, sellState)

    fun commitment(id: UUID): Commitment? = _commitments.value.firstOrNull { it.id == id }

    /** Everything the stats row and the weekly report need, in one pass. */
    fun stats(): Stats = real.fold(Stats(0, 0, 0)) { acc, commitment ->
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
        // A rehearsal proves nothing about a real habit. Clear its chain, drop the row,
        // leave every streak alone -- otherwise the demo would inflate the number the app
        // exists to keep honest.
        if (commitment(commitmentId)?.isRehearsal == true) {
            endRehearsal()
            return
        }

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
        // Real commitments only. A rehearsal that survived a reboot would ring twenty
        // seconds after the phone came back, which is a jump scare, not a demo.
        real.filter { it.isEnabled }.forEach { alarms.schedule(it) }
    }

    // MARK: - Rehearsal

    /**
     * Arm a compressed run of the whole mechanic. See [Commitment.rehearsal].
     *
     * The proof kind is passed in rather than fixed: a timer rehearsal and a photo
     * rehearsal exercise completely different screens, and the one worth showing is
     * whichever the user is about to rely on.
     */
    suspend fun startRehearsal(proofKind: Commitment.ProofKind) {
        endRehearsal()
        val commitment = Commitment.rehearsal(
            fireAtMillis = alarms.rehearsalFireMillis(),
            proofKind = proofKind,
        )
        mutate { it + commitment }
        alarms.armRehearsal(commitment)
    }

    /**
     * Tear it down without touching any streak. Called when the rehearsal is proved, when
     * a new one replaces it, and when its chain has run out.
     */
    suspend fun endRehearsal() {
        val existing = rehearsal ?: return
        mutate { list -> list.filterNot { it.isRehearsal } }
        alarms.cancel(existing.id)
    }

    /**
     * A rehearsal is over the moment its chain runs out, whether it was proved, dismissed
     * five times, or ignored. Called when the list comes forward: leaving a "Rehearsal
     * armed" banner on a rehearsal that will never ring again is worse than never having
     * shown one.
     */
    suspend fun reconcileRehearsal() {
        val existing = rehearsal ?: return
        if (alarms.isSpent(existing.id)) endRehearsal()
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

    /**
     * True when a file exists that could not be read. Everything downstream has to treat
     * that as "unknown", never as "empty".
     */
    @Volatile
    var loadFailed: Boolean = false
        private set

    private fun loadFromDisk(): List<Commitment> {
        if (!file.exists()) return emptyList()
        return runCatching {
            json.decodeFromString<List<Commitment>>(file.readText()).also { loadFailed = false }
        }.getOrElse {
            // This used to be `.getOrElse { emptyList() }`, which turned any decode error
            // into an empty list -- and the next save wrote that emptiness over the file.
            // The rename dance below protects against a truncated write; it does nothing
            // about a file that parses badly for any other reason. Silence is the wrong
            // answer to "I could not read your data".
            loadFailed = true
            emptyList()
        }
    }

    private fun saveToDisk(commitments: List<Commitment>) {
        // Never overwrite a file we failed to read. Better a stuck app the user can
        // report than a quietly erased one they cannot.
        if (loadFailed) return
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

        /**
         * Whether the + button opens the editor or the paywall.
         *
         * A paywall that cannot sell anything is not a paywall, it is a locked door. When
         * RevenueCat has told us the shelf is empty — no Play products yet, or no key in
         * this build — the free limit does not apply, because the only way past it would
         * be a purchase the user is not being offered. This does not soften the number:
         * [FREE_COMMITMENT_LIMIT] is still two the moment there is something to buy.
         *
         * [SellState.UNKNOWN] keeps the limit. Not having heard back yet is not evidence
         * the shelf is empty, and guessing the generous way there gives a free commitment
         * to anyone who taps + faster than the network answers.
         *
         * Free of the instance so it can be tested without an Android Context.
         */
        fun mayAddAnother(activeCount: Int, isPro: Boolean, sellState: SellState): Boolean {
            if (sellState == SellState.NOTHING_TO_SELL) return true
            return isPro || activeCount < FREE_COMMITMENT_LIMIT
        }

        @Volatile
        private var instance: CommitmentStore? = null

        fun get(context: Context): CommitmentStore =
            instance ?: synchronized(this) {
                instance ?: CommitmentStore(context).also { instance = it }
            }
    }
}
