package app.lockin.ui

import androidx.compose.foundation.background
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
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CameraAlt
import androidx.compose.material.icons.filled.LocalFireDepartment
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import app.lockin.ui.theme.Lockin

/**
 * Three screens, no account, no permission prompt. The only job here is to make the user
 * picture the alarm going off — then hand them straight to creating one.
 *
 * Onboarding is where roughly 80% of conversion is decided. Give it as much care as the
 * alarm engine, and rewrite it once you have 100 real users to watch.
 */
@Composable
fun OnboardingScreen(onFinished: () -> Unit) {
    val palette = Lockin.palette
    val pagerState = rememberPagerState(pageCount = { 3 })

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.ground),
    ) {
        Column(Modifier.fillMaxSize().systemBarsPadding()) {
            HorizontalPager(
                state = pagerState,
                modifier = Modifier.weight(1f),
            ) { page ->
                when (page) {
                    0 -> Slide(
                        icon = Icons.Filled.NotificationsActive,
                        title = "It rings through silent",
                        body = "Do Not Disturb, vibrate only, volume at zero. Nagg doesn't care.",
                    )

                    1 -> Slide(
                        icon = Icons.Filled.CameraAlt,
                        title = "You can't fake it",
                        body = "The alarm keeps coming back until you photograph your desk, " +
                            "scan your code, or start the timer.",
                    )

                    else -> Slide(
                        icon = Icons.Filled.LocalFireDepartment,
                        title = "Then it counts the days",
                        body = "And every excuse you made, in a report you'll hate on Sundays.",
                    )
                }
            }

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 20.dp),
                horizontalArrangement = Arrangement.Center,
            ) {
                repeat(3) { index ->
                    Box(
                        Modifier
                            .padding(horizontal = 4.dp)
                            .size(if (index == pagerState.currentPage) 8.dp else 6.dp)
                            .background(
                                if (index == pagerState.currentPage) palette.ink else palette.line,
                                CircleShape,
                            ),
                    )
                }
            }

            Button(
                onClick = onFinished,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 12.dp),
                shape = RoundedCornerShape(11.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = palette.ink,
                    contentColor = palette.ground,
                ),
                contentPadding = PaddingValues(vertical = 15.dp),
            ) {
                Text(
                    text = if (pagerState.currentPage == 2) "Set my first commitment" else "Skip",
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                )
            }
        }
    }
}

@Composable
private fun Slide(icon: ImageVector, title: String, body: String) {
    val palette = Lockin.palette
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = palette.alarm,
            modifier = Modifier.size(64.dp),
        )
        Spacer(Modifier.height(20.dp))
        Text(
            text = title,
            fontSize = 30.sp,
            lineHeight = 36.sp,
            fontWeight = FontWeight.Bold,
            color = palette.ink,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            text = body,
            fontSize = 15.sp,
            lineHeight = 23.sp,
            color = palette.ink2,
            textAlign = TextAlign.Center,
        )
    }
}
