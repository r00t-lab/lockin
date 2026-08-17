package app.lockin.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * The prototype's palette, transcribed hex-for-hex from `prototype/index.html`.
 *
 * These are semantic roles (ground / surface / ink), not Material roles, which is why
 * they live in their own [LockinPalette] rather than being forced into a
 * [androidx.compose.material3.ColorScheme]. A Material scheme is still provided so the
 * stock M3 components (text fields, sheets, ripples) land somewhere sane.
 *
 * No dynamic color. The alarm red is the brand; letting a device wallpaper repaint it
 * would be the one theming decision that costs the product its recognisability.
 */
@Immutable
data class LockinPalette(
    val ground: Color,
    val surface: Color,
    val sunk: Color,
    val ink: Color,
    val ink2: Color,
    val ink3: Color,
    val line: Color,
    val go: Color,
    val goBg: Color,
    val alarm: Color,
    val alarmDeep: Color,
    val alarmPale: Color,
)

private val LightPalette = LockinPalette(
    ground = Color(0xFFEFEEE9),
    surface = Color(0xFFFBFAF7),
    sunk = Color(0xFFE4E3DC),
    ink = Color(0xFF17171A),
    ink2 = Color(0xFF5C5C58),
    ink3 = Color(0xFF8E8E88),
    line = Color(0xFFD5D4CC),
    go = Color(0xFF0F6E56),
    goBg = Color(0xFFDCEDE6),
    alarm = Color(0xFFC7351A),
    alarmDeep = Color(0xFF4A1409),
    alarmPale = Color(0xFFF6D9D2),
)

private val DarkPalette = LockinPalette(
    ground = Color(0xFF121214),
    surface = Color(0xFF1C1C1F),
    sunk = Color(0xFF26262A),
    ink = Color(0xFFEAEAE6),
    ink2 = Color(0xFFA3A39D),
    ink3 = Color(0xFF6E6E69),
    line = Color(0xFF303035),
    go = Color(0xFF5DCAA5),
    goBg = Color(0xFF14332A),
    alarm = Color(0xFFE85236),
    alarmDeep = Color(0xFF4A1409),
    alarmPale = Color(0xFFF6D9D2),
)

val LocalLockinPalette = staticCompositionLocalOf { LightPalette }

/** Tabular, monospaced numerals — the stats row and the countdown must not jitter. */
val MonoNumerals = TextStyle(
    fontFamily = FontFamily.Monospace,
    fontWeight = FontWeight.SemiBold,
)

private val LockinTypography = Typography()

@Composable
fun LockinTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val palette = if (darkTheme) DarkPalette else LightPalette

    val colorScheme = if (darkTheme) {
        darkColorScheme(
            primary = palette.ink,
            onPrimary = palette.ground,
            secondary = palette.go,
            background = palette.ground,
            onBackground = palette.ink,
            surface = palette.surface,
            onSurface = palette.ink,
            surfaceVariant = palette.sunk,
            onSurfaceVariant = palette.ink2,
            outline = palette.line,
            error = palette.alarm,
        )
    } else {
        lightColorScheme(
            primary = palette.ink,
            onPrimary = palette.ground,
            secondary = palette.go,
            background = palette.ground,
            onBackground = palette.ink,
            surface = palette.surface,
            onSurface = palette.ink,
            surfaceVariant = palette.sunk,
            onSurfaceVariant = palette.ink2,
            outline = palette.line,
            error = palette.alarm,
        )
    }

    CompositionLocalProvider(LocalLockinPalette provides palette) {
        MaterialTheme(
            colorScheme = colorScheme,
            typography = LockinTypography,
            content = content,
        )
    }
}

/** Shorthand so screens read `Lockin.palette.alarm` instead of the local's full name. */
object Lockin {
    val palette: LockinPalette
        @Composable get() = LocalLockinPalette.current
}

/** Sizes lifted from the prototype so the two stay visually identical. */
object LockinSizes {
    const val CARD_RADIUS = 14
    const val BUTTON_RADIUS = 11
}

val StatNumber = TextStyle(
    fontFamily = FontFamily.Monospace,
    fontWeight = FontWeight.SemiBold,
    fontSize = 26.sp,
)

val CountdownNumber = TextStyle(
    fontFamily = FontFamily.Monospace,
    fontWeight = FontWeight.SemiBold,
    fontSize = 58.sp,
)

val MetaText = TextStyle(
    fontFamily = FontFamily.Monospace,
    fontSize = 12.sp,
)

val EyebrowText = TextStyle(
    fontFamily = FontFamily.Monospace,
    fontSize = 11.sp,
    letterSpacing = 1.5.sp,
)
