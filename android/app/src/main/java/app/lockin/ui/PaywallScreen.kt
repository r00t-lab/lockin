package app.lockin.ui

import android.app.Activity
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import app.lockin.billing.SellState
import app.lockin.billing.SubscriptionService
import app.lockin.ui.theme.EyebrowText
import app.lockin.ui.theme.Lockin
import com.revenuecat.purchases.Package
import com.revenuecat.purchases.PackageType
import kotlinx.coroutines.launch

/**
 * The paywall earns more than any feature you could build instead. Treat it as the
 * product, not as a tax on the product.
 *
 * Pricing rationale (RevenueCat, 115k apps, 2026): median high-priced apps convert
 * downloads roughly 2x better than low-priced ones — 2.8% vs 1.4%. Cheap pricing is
 * punished twice, once on price and once on conversion. Do not discount your way in.
 * Productivity revenue is ~77% monthly, so lead with monthly and offer annual as the
 * saving, rather than the reverse.
 */
@Composable
fun PaywallScreen(
    subscriptions: SubscriptionService,
    onDismiss: () -> Unit,
) {
    val palette = Lockin.palette
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val offering by subscriptions.offering.collectAsStateWithLifecycle()
    val sellState by subscriptions.sellState.collectAsStateWithLifecycle()
    val isPurchasing by subscriptions.isPurchasing.collectAsStateWithLifecycle()

    var selected by remember { mutableStateOf<Package?>(null) }

    LaunchedEffect(Unit) {
        subscriptions.refresh()
    }
    LaunchedEffect(offering) {
        if (selected == null) selected = offering?.availablePackages?.firstOrNull()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.ground)
            .systemBarsPadding()
            .padding(horizontal = 20.dp, vertical = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(12.dp))
        Text(
            "You've used your two free commitments",
            fontSize = 22.sp,
            lineHeight = 28.sp,
            fontWeight = FontWeight.Bold,
            color = palette.ink,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(10.dp))
        Text(
            "Unlimited commitments and the weekly report on every " +
                "excuse you made.",
            fontSize = 14.sp,
            lineHeight = 21.sp,
            color = palette.ink2,
            textAlign = TextAlign.Center,
        )

        Spacer(Modifier.height(28.dp))

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            val packages = offering?.availablePackages.orEmpty()

            // An empty paywall is the worst version of this screen: the user taps the
            // button, nothing happens, and they conclude the app is broken rather than
            // unfinished. Say which it is -- and say the right one, because "we have not
            // heard back" and "there is nothing for sale" want opposite things from the
            // reader. Reaching this screen with an empty shelf is now the rare path: when
            // RevenueCat confirms there is nothing to sell, the + button stops sending
            // anyone here at all.
            if (packages.isEmpty()) {
                val unreachable = sellState == SellState.UNKNOWN
                val eyebrow = if (unreachable) "CAN'T REACH THE STORE" else "NOTHING TO SELL YET"
                val explanation = if (unreachable) {
                    "We couldn't load the subscriptions just now — usually the network. " +
                        "Everything already on your phone keeps working; try again later."
                } else {
                    "Subscriptions aren't set up on this build, so there's nothing to buy " +
                        "and nothing to pay for. The two-commitment limit is off until there is."
                }
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(palette.surface, RoundedCornerShape(14.dp))
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    Text(eyebrow, style = EyebrowText, color = palette.ink3)
                    Text(
                        explanation,
                        fontSize = 14.sp,
                        lineHeight = 21.sp,
                        color = palette.ink2,
                    )
                }
            }

            packages.forEach { pkg ->
                PackageRow(
                    packageToPurchase = pkg,
                    selected = selected?.identifier == pkg.identifier,
                    onClick = { selected = pkg },
                )
            }
        }

        Button(
            onClick = {
                val activity = context.findActivity() ?: return@Button
                val pkg = selected ?: offering?.availablePackages?.firstOrNull() ?: return@Button
                scope.launch {
                    if (subscriptions.purchase(activity, pkg)) onDismiss()
                }
            },
            enabled = !isPurchasing,
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(11.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = palette.ink,
                contentColor = palette.ground,
            ),
            contentPadding = PaddingValues(vertical = 15.dp),
        ) {
            Text(
                if (isPurchasing) "…" else "Start free trial",
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
            )
        }

        Row(
            modifier = Modifier.padding(top = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            TextButton(onClick = { scope.launch { subscriptions.restore() } }) {
                Text("Restore", fontSize = 12.sp, color = palette.ink3)
            }
            TextButton(onClick = { context.open("https://lockin.app/terms") }) {
                Text("Terms", fontSize = 12.sp, color = palette.ink3)
            }
            TextButton(onClick = { context.open("https://lockin.app/privacy") }) {
                Text("Privacy", fontSize = 12.sp, color = palette.ink3)
            }
        }

        TextButton(onClick = onDismiss) {
            Text("Not now", fontSize = 13.sp, color = palette.ink3)
        }
    }
}

@Composable
/** " / month" or " / year", read off the package rather than hard-coded per row. */
private fun periodSuffix(pkg: Package): String = when (pkg.packageType) {
    PackageType.MONTHLY -> " / month"
    PackageType.ANNUAL -> " / year"
    PackageType.WEEKLY -> " / week"
    PackageType.SIX_MONTH -> " / 6 months"
    PackageType.THREE_MONTH -> " / 3 months"
    PackageType.TWO_MONTH -> " / 2 months"
    PackageType.LIFETIME -> ""
    else -> ""
}

private fun PackageRow(
    packageToPurchase: Package,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val palette = Lockin.palette
    val product = packageToPurchase.product

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                if (selected) palette.goBg else palette.surface,
                RoundedCornerShape(14.dp),
            )
            .border(
                1.dp,
                if (selected) palette.go else palette.line,
                RoundedCornerShape(14.dp),
            )
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                // ⚠️ SIGNATURE NOTE: RevenueCat's Android StoreProduct exposes `title` and
                // `price.formatted`, where iOS uses `localizedTitle` /
                // `localizedPriceString`. Verify against the SDK version you resolve.
                text = product.title,
                fontSize = 15.sp,
                fontWeight = FontWeight.SemiBold,
                color = palette.ink,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                // The billing period is printed next to the price rather than left to the
                // product title. App Review rejected the iOS build under 3.1.2(c) for
                // exactly this: "Nagg Pro Monthly" reads as a duration to us and as a name
                // to a reviewer, and Play's policy asks for the same disclosure.
                text = product.price.formatted + periodSuffix(packageToPurchase),
                fontSize = 13.sp,
                color = palette.ink2,
            )
        }

        Box(
            modifier = Modifier
                .size(22.dp)
                .background(if (selected) palette.go else Color.Transparent, CircleShape)
                .border(1.dp, if (selected) palette.go else palette.line, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            if (selected) {
                Icon(
                    Icons.Filled.Check,
                    contentDescription = null,
                    tint = palette.ground,
                    modifier = Modifier.size(14.dp),
                )
            }
        }
    }
}

/** Play Billing needs a real Activity; Compose only hands us a Context. */
private fun android.content.Context.findActivity(): Activity? {
    var current = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}

private fun android.content.Context.open(url: String) {
    runCatching {
        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    }
}
