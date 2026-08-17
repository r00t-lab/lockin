package app.lockin

import android.app.Application
import app.lockin.alarm.AlarmNotifications
import app.lockin.billing.SubscriptionService

class LockinApplication : Application() {

    override fun onCreate() {
        super.onCreate()

        // Create the channel before anything can post to it. A notification aimed at a
        // channel that does not exist yet is silently dropped on API 26+, which on this
        // app means an alarm that simply never appears.
        AlarmNotifications.createChannels(this)

        SubscriptionService.configure(this, REVENUECAT_API_KEY)
    }

    private companion object {
        /**
         * Replace with your RevenueCat public SDK key (`goog_…`). It is safe to ship in
         * the binary — it is a public key — but do not paste your *secret* key here.
         *
         * Note the prefix differs from iOS: the Play key is `goog_…`, the App Store key
         * is `appl_…`, and they are not interchangeable.
         */
        const val REVENUECAT_API_KEY = "goog_REPLACE_ME"
    }
}
