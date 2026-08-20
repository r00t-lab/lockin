package app.lockin.data

import app.lockin.billing.SellState
import app.lockin.data.CommitmentStore.Companion.FREE_COMMITMENT_LIMIT
import app.lockin.data.CommitmentStore.Companion.mayAddAnother
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The + button's decision, which is the one place in the app where a wrong answer either
 * gives away the product or locks somebody out of it.
 *
 * This shipped broken on Android once: the Play products did not exist, so the paywall had
 * nothing on it, and the free limit still applied — a tester who made two commitments
 * could neither add a third nor pay to. Runs on the JVM, no Context — `./gradlew test`.
 */
class PaywallGateTest {

    @Test
    fun `a user who cannot be sold anything is never stopped`() {
        // The bug this file exists for. No products on Play, so no purchase is on offer;
        // stopping them here would be a door with no handle on either side.
        assertTrue(mayAddAnother(activeCount = 99, isPro = false, sellState = SellState.NOTHING_TO_SELL))
    }

    @Test
    fun `silence is not the same as an empty shelf`() {
        // UNKNOWN means the lookup has not come back. Guessing generously here hands a
        // free commitment to anyone who taps + before the network answers.
        assertFalse(mayAddAnother(FREE_COMMITMENT_LIMIT, isPro = false, sellState = SellState.UNKNOWN))
    }

    @Test
    fun `the limit is still two once there is something to buy`() {
        assertTrue(mayAddAnother(FREE_COMMITMENT_LIMIT - 1, isPro = false, sellState = SellState.READY))
        assertFalse(mayAddAnother(FREE_COMMITMENT_LIMIT, isPro = false, sellState = SellState.READY))
        assertFalse(mayAddAnother(FREE_COMMITMENT_LIMIT + 1, isPro = false, sellState = SellState.READY))
    }

    @Test
    fun `pro has no ceiling in any state`() {
        for (state in SellState.values()) {
            assertTrue("pro blocked in $state", mayAddAnother(99, isPro = true, sellState = state))
        }
    }

    @Test
    fun `an empty shelf lifts the limit rather than lowering it`() {
        // Guards the shape of the rule, not just one value: NOTHING_TO_SELL must be at
        // least as permissive as READY for every count, never stricter.
        for (count in 0..5) {
            val ready = mayAddAnother(count, isPro = false, sellState = SellState.READY)
            val nothing = mayAddAnother(count, isPro = false, sellState = SellState.NOTHING_TO_SELL)
            assertTrue("count=$count went the wrong way", nothing || !ready)
        }
    }
}
