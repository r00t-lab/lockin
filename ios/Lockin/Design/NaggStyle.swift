import SwiftUI

/// The visual identity, ported from `prototype/index.html`.
///
/// ## Why this file exists
/// The list screen used to be a stock `List` on the grounds that "the product's
/// personality lives in the alarm, not here". That was right about where the tension is
/// and wrong about what ships: the screen recording *is* the advertising, and a stock
/// iOS list looks like every other habit app in the store. The prototype already had an
/// identity people reacted to. This is that identity, in SwiftUI, with nothing invented.
///
/// ## The rules, so a new screen cannot drift
/// 1. **Paper, not white.** The ground is a warm off-white; cards sit slightly *lighter*
///    than the ground, not on a grey. Pure `#FFF` and pure `systemBackground` never appear.
/// 2. **Monospace is for facts.** Times, streaks, counters, eyebrows, anything the user
///    reads as data. Prose is the system sans. Mixing them the other way round is the
///    fastest way to make this look generic again.
/// 3. **Two accents and no more.** `alarm` red means unfinished or destructive. `go`
///    green means proved. Nothing else gets a colour — no blues, no system tint.
/// 4. **Uppercase micro-labels**, 11pt with wide tracking, for anything that labels
///    something else. They carry a lot of the character.
/// 5. **One-pixel lines, 14pt corners.** No shadows, no gradients, no material blur.
///
/// Colours are built in code rather than in `Assets.xcassets` on purpose: this project is
/// developed without a Mac, and a JSON colour set edited blind is a colour set nobody
/// checks. `UIColor(dynamicProvider:)` gives the same light/dark behaviour in one line.
enum Nagg {

    // MARK: - Palette

    static let ground  = dynamic(light: 0xEFEEE9, dark: 0x121214)
    static let surface = dynamic(light: 0xFBFAF7, dark: 0x1C1C1F)
    static let sunk    = dynamic(light: 0xE4E3DC, dark: 0x26262A)

    static let ink     = dynamic(light: 0x17171A, dark: 0xEAEAE6)
    /// Secondary prose and card meta.
    static let ink2    = dynamic(light: 0x5C5C58, dark: 0xA3A39D)
    /// Labels, hints, anything that must recede.
    static let ink3    = dynamic(light: 0x8E8E88, dark: 0x6E6E69)

    static let line    = dynamic(light: 0xD5D4CC, dark: 0x303035)

    static let go      = dynamic(light: 0x0F6E56, dark: 0x5DCAA5)
    static let goBg    = dynamic(light: 0xDCEDE6, dark: 0x14332A)

    static let alarm   = dynamic(light: 0xC7351A, dark: 0xE85236)
    /// Fixed both ways — these two only ever appear *on* the red alarm screen, which
    /// does not change with the system theme. A ringing alarm is red at 3pm and at 3am.
    static let alarmDeep = Color(hex: 0x4A1409)
    static let alarmPale = Color(hex: 0xF6D9D2)

    static let radius: CGFloat = 14

    // MARK: - Type

    /// Facts: times, counters, streaks. Tabular so digits do not jitter as they change.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    /// Prose.
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    // MARK: - Colour plumbing

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

// MARK: - Text treatments

extension View {
    /// The 11pt uppercase label that sits above fields and beside numbers.
    ///
    /// Takes its colour as an argument rather than letting the caller chain another
    /// `.foregroundStyle` afterwards — the outer one would lose to the one set in here,
    /// and the label would silently stay grey.
    func naggLabel(_ color: Color = Nagg.ink3) -> some View {
        font(Nagg.mono(11, .medium))
            .tracking(1.0)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    /// Digits that change in place — streaks, counters, clocks.
    func naggFigure(_ size: CGFloat) -> some View {
        font(Nagg.mono(size))
            .monospacedDigit()
            .contentTransition(.numericText())
    }

    /// A hairline that reads as drawn rather than as a system separator.
    func naggCard(done: Bool = false) -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(done ? Nagg.goBg : Nagg.surface)
            .clipShape(.rect(cornerRadius: Nagg.radius))
            .overlay {
                RoundedRectangle(cornerRadius: Nagg.radius)
                    .stroke(done ? .clear : Nagg.line, lineWidth: 1)
            }
    }

    /// Paints the warm ground edge to edge, including behind the navigation bar.
    func naggGround() -> some View {
        background(Nagg.ground.ignoresSafeArea())
    }
}

// MARK: - Buttons

/// Filled, ink on paper. The one action a screen actually wants.
struct NaggPrimaryButton: ButtonStyle {
    var tint: Color = Nagg.ink
    var label: Color = Nagg.ground

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Nagg.sans(15, .medium))
            .foregroundStyle(label)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(tint)
            .clipShape(.rect(cornerRadius: 11))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// Outlined. Everything that is not the one action.
struct NaggGhostButton: ButtonStyle {
    var tint: Color = Nagg.ink

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Nagg.sans(15))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background {
                RoundedRectangle(cornerRadius: 11).stroke(Nagg.line, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
    }
}

/// The way out. Quiet on purpose — it must be findable and never inviting.
struct NaggBailButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Nagg.sans(13))
            .foregroundStyle(Nagg.ink3)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// MARK: - Hex

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

private extension Color {
    init(hex: UInt32) { self.init(UIColor(hex: hex)) }
}
