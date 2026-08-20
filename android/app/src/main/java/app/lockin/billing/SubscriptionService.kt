package app.lockin.billing

import android.app.Activity
import android.content.Context
import com.revenuecat.purchases.LogLevel
import com.revenuecat.purchases.Offering
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PurchaseParams
import com.revenuecat.purchases.Purchases
import com.revenuecat.purchases.PurchasesConfiguration
import com.revenuecat.purchases.PurchasesTransactionException
import com.revenuecat.purchases.awaitCustomerInfo
import com.revenuecat.purchases.awaitOfferings
import com.revenuecat.purchases.awaitPurchase
import com.revenuecat.purchases.awaitRestore
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Thin wrapper over RevenueCat. Everything the rest of the app needs is [isPro].
 *
 * Direct port of `SubscriptionService.swift`, including the reasoning: RevenueCat is free
 * until $2,500/mo tracked revenue, which is well past the point where paying for it stops
 * hurting. Do not hand-roll Google Play Billing for v1.
 *
 * ⚠️ SIGNATURE NOTE: written against the RevenueCat Android SDK v8 coroutine surface
 * (`awaitCustomerInfo` / `awaitOfferings` / `awaitPurchase` / `awaitRestore`). Those
 * extensions were `@ExperimentalPreviewRevenueCatPurchasesAPI` in the v6 era and went
 * stable later; none of it could be compiled here. If they do not resolve, either add the
 * opt-in annotation or fall back to the listener-based `Purchases.sharedInstance.purchase(...)`
 * overloads. Nothing outside this file needs to change either way.
 */
/**
 * Whether Pro can actually be bought on this device, right now.
 *
 * The distinction that earns this type is between *we have not looked yet* and *we looked
 * and the shelf is empty*. Collapsing the two either hands a free commitment to anyone who
 * taps + before the network answers, or locks a user behind a paywall with nothing on it.
 * Only the second state lifts the free limit.
 */
enum class SellState {
    /** No answer yet, or the last lookup failed. Assume Pro is buyable and keep the limit. */
    UNKNOWN,

    /** RevenueCat answered and offered nothing. Nobody can pay, so nobody may be charged. */
    NOTHING_TO_SELL,

    /** There are packages on the paywall. Normal behaviour. */
    READY,
}

class SubscriptionService private constructor() {

    private val _sellState = MutableStateFlow(SellState.UNKNOWN)
    val sellState: StateFlow<SellState> = _sellState.asStateFlow()

    private val _isPro = MutableStateFlow(false)
    val isPro: StateFlow<Boolean> = _isPro.asStateFlow()

    private val _offering = MutableStateFlow<Offering?>(null)
    val offering: StateFlow<Offering?> = _offering.asStateFlow()

    private val _isPurchasing = MutableStateFlow(false)
    val isPurchasing: StateFlow<Boolean> = _isPurchasing.asStateFlow()

    suspend fun refresh() {
        if (!isConfigured) {
            // No key, so there is no shelf to look at and never will be on this build.
            _sellState.value = SellState.NOTHING_TO_SELL
            return
        }

        runCatching {
            val info = Purchases.sharedInstance.awaitCustomerInfo()
            _isPro.value = info.entitlements[ENTITLEMENT_ID]?.isActive == true
        }

        // Deliberately not one runCatching with the call above: a network failure must
        // leave the state UNKNOWN. Only an answer we actually received can say the shelf
        // is empty, because that answer is what unlocks the free limit.
        runCatching {
            Purchases.sharedInstance.awaitOfferings().current
        }.onSuccess { current ->
            _offering.value = current
            _sellState.value = if (current?.availablePackages.isNullOrEmpty()) {
                SellState.NOTHING_TO_SELL
            } else {
                SellState.READY
            }
        }
    }

    /**
     * Google Play Billing runs the purchase dialog from an Activity, so unlike StoreKit
     * this cannot be called from a plain view model. The paywall passes its host activity
     * down. That is the single structural difference from the iOS version.
     */
    suspend fun purchase(activity: Activity, packageToPurchase: Package): Boolean {
        if (!isConfigured) return false
        _isPurchasing.value = true
        try {
            val result = Purchases.sharedInstance.awaitPurchase(
                PurchaseParams.Builder(activity, packageToPurchase).build(),
            )
            _isPro.value = result.customerInfo.entitlements[ENTITLEMENT_ID]?.isActive == true
            return _isPro.value
        } catch (e: PurchasesTransactionException) {
            // A user backing out of the sheet is the common path, not an error. Swallow it
            // silently — showing "purchase failed" to someone who just changed their mind
            // is how you turn a maybe into a never.
            if (!e.userCancelled) refresh()
            return false
        } catch (e: Exception) {
            return false
        } finally {
            _isPurchasing.value = false
        }
    }

    /**
     * Play does not mandate a restore button the way Apple does, but keep it: it is the
     * only recovery path for a user who changed devices, and it is two lines.
     */
    suspend fun restore(): Boolean {
        if (!isConfigured) return false
        return runCatching {
            val info = Purchases.sharedInstance.awaitRestore()
            _isPro.value = info.entitlements[ENTITLEMENT_ID]?.isActive == true
            _isPro.value
        }.getOrDefault(false)
    }

    companion object {

        /**
         * Entitlement identifier as configured in the RevenueCat dashboard. Must match
         * the iOS app exactly, or a subscriber who switches platforms loses Pro.
         */
        const val ENTITLEMENT_ID = "pro"

        /** The value that ships in the repo when no key has been pasted in. */
        private const val PLACEHOLDER_KEY = "goog_REPLACE_ME"

        /**
         * False until a real key has been handed to [configure]. Every call that reaches
         * RevenueCat checks it.
         *
         * Configuring with the placeholder does not fail loudly, it fails in a loop — the
         * iOS side burned battery and buried the system log doing exactly this while we
         * were reading that log to chase an unrelated bug.
         */
        @Volatile
        var isConfigured = false
            private set

        /**
         * Call once, from [LockinApplication][app.lockin.LockinApplication.onCreate],
         * before any other RevenueCat call.
         *
         * Refuses the placeholder rather than passing it through.
         */
        fun configure(context: Context, apiKey: String) {
            if (apiKey == PLACEHOLDER_KEY || !apiKey.startsWith("goog_")) {
                isConfigured = false
                return
            }
            Purchases.logLevel = LogLevel.WARN
            Purchases.configure(
                PurchasesConfiguration.Builder(context, apiKey).build(),
            )
            isConfigured = true
        }

        @Volatile
        private var instance: SubscriptionService? = null

        fun get(): SubscriptionService =
            instance ?: synchronized(this) {
                instance ?: SubscriptionService().also { instance = it }
            }
    }
}
