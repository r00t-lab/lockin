import SwiftUI

/// Three screens, no account, no permission prompt. The only job here is to make the
/// user picture the alarm going off — then hand them straight to creating one.
///
/// Onboarding is where roughly 80% of your conversion is decided. Give it as much care
/// as the alarm engine, and rewrite it once you have 100 real users to watch.
///
/// The SF Symbols are gone. A 64pt glyph is what every onboarding in the store looks
/// like; a claim set in the app's own type is what this app looks like. Each slide is
/// one sentence the user has to disagree with or accept, and the third one is red —
/// the first time they see the alarm colour is before they ever hear it.
struct OnboardingView: View {

    @Binding var hasOnboarded: Bool
    @State private var page = 0

    private struct Slide {
        let index: String
        let title: String
        let body: String
        let accent: Bool
    }

    private let slides = [
        Slide(
            index: "01",
            title: "It rings through Silent.",
            body: "Focus mode, Do Not Disturb, volume at zero. Nagg doesn't care.",
            accent: false
        ),
        Slide(
            index: "02",
            title: "You can't fake it.",
            body: "The alarm keeps coming back until you photograph your desk, scan your code, or start the timer.",
            accent: false
        ),
        Slide(
            index: "03",
            title: "Then it counts the days.",
            body: "And every excuse you made, in a report you'll hate on Sundays.",
            accent: true
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    slideView(slide).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            dots.padding(.bottom, 24)

            Button(page == slides.count - 1 ? "Set my first commitment" : "Next") {
                if page == slides.count - 1 {
                    hasOnboarded = true
                } else {
                    withAnimation { page += 1 }
                }
            }
            .buttonStyle(NaggPrimaryButton())
            .padding(.horizontal, 20)
            .padding(.bottom, 10)

            Button("Skip") { hasOnboarded = true }
                .buttonStyle(NaggBailButton())
                .opacity(page == slides.count - 1 ? 0 : 1)
                .padding(.bottom, 8)
        }
        .naggGround()
    }

    private func slideView(_ slide: Slide) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer()
            Text(slide.index).naggLabel(slide.accent ? Nagg.alarm : Nagg.ink3)
            Text(slide.title)
                .font(Nagg.sans(34, .medium))
                .lineSpacing(2)
                .foregroundStyle(slide.accent ? Nagg.alarm : Nagg.ink)
            Text(slide.body)
                .font(Nagg.sans(16))
                .lineSpacing(5)
                .foregroundStyle(Nagg.ink2)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }

    private var dots: some View {
        HStack(spacing: 6) {
            ForEach(slides.indices, id: \.self) { index in
                Capsule()
                    .fill(index == page ? Nagg.ink : Nagg.line)
                    .frame(width: index == page ? 18 : 6, height: 6)
                    .animation(.easeOut(duration: 0.18), value: page)
            }
        }
    }
}
