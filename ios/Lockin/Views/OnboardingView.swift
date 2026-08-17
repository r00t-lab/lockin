import SwiftUI

/// Three screens, no account, no permission prompt. The only job here is to make the
/// user picture the alarm going off — then hand them straight to creating one.
///
/// Onboarding is where roughly 80% of your conversion is decided. Give it as much care
/// as the alarm engine, and rewrite it once you have 100 real users to watch.
struct OnboardingView: View {

    @Binding var hasOnboarded: Bool
    @State private var page = 0

    var body: some View {
        TabView(selection: $page) {
            slide(
                icon: "iphone.gen3.radiowaves.left.and.right",
                title: "It rings through Silent",
                body: "Focus mode, Do Not Disturb, volume at zero. Lockin doesn't care.",
                tag: 0
            )
            slide(
                icon: "camera.viewfinder",
                title: "You can't fake it",
                body: "The alarm keeps coming back until you photograph your desk, scan your code, or start the timer.",
                tag: 1
            )
            VStack(spacing: 32) {
                slideContent(
                    icon: "flame.fill",
                    title: "Then it counts the days",
                    body: "And every excuse you made, in a report you'll hate on Sundays."
                )
                Button("Set my first commitment") {
                    hasOnboarded = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 40)
            }
            .tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }

    private func slide(icon: String, title: String, body: String, tag: Int) -> some View {
        slideContent(icon: icon, title: title, body: body).tag(tag)
    }

    private func slideContent(icon: String, title: String, body: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text(title)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }
}
