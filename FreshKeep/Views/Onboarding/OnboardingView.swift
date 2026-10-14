import SwiftUI

/// Three-page welcome flow with animated illustrations. The last page asks for
/// notification permission so expiry reminders can be delivered.
struct OnboardingView: View {
    var onFinish: () -> Void

    @Environment(AppServices.self) private var services
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        .init(symbol: "leaf.fill", emojis: ["🍎", "🥕", "🥛", "🍞"], title: "Waste less, save more",
              message: "A third of the food we buy is thrown away. FreshKeep helps you eat it before it's too late."),
        .init(symbol: "camera.viewfinder", emojis: ["📸", "🍌", "🔍", "🍅"], title: "Snap to add",
              message: "Point your camera at food or a best-before label. On-device AI fills in the details — privately."),
        .init(symbol: "bell.badge.fill", emojis: ["⏰", "🍳", "💚", "🥗"], title: "Get nudged in time",
              message: "We'll remind you before things expire and suggest recipes that use them up.")
    ]

    var body: some View {
        VStack(spacing: Spacing.xl) {
            HStack {
                Spacer()
                if page < pages.count - 1 {
                    Button("Skip") { finish() }
                        .font(.rounded(.body, weight: .medium))
                        .accessibilityIdentifier("onboarding.skip")
                }
            }
            .frame(height: 44)
            .padding(.horizontal)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    OnboardingPageView(page: pages[index], isActive: page == index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button(page == pages.count - 1 ? "Get started" : "Next") {
                if page == pages.count - 1 {
                    finish()
                } else {
                    withAnimation(.snappySpring) { page += 1 }
                }
            }
            .buttonStyle(.primary)
            .padding(.horizontal, Spacing.xl)
            .padding(.bottom, Spacing.l)
            .accessibilityIdentifier("onboarding.next")
        }
        .background(Color.appBackground.ignoresSafeArea())
        .sensoryFeedback(.selection, trigger: page)
    }

    private func finish() {
        Task {
            _ = await services.notifications.requestAuthorization()
            onFinish()
        }
    }
}

struct OnboardingPage {
    let symbol: String
    let emojis: [String]
    let title: String
    let message: String
}

private struct OnboardingPageView: View {
    let page: OnboardingPage
    let isActive: Bool

    var body: some View {
        VStack(spacing: Spacing.xl) {
            ZStack {
                Circle()
                    .fill(.brandGradient)
                    .frame(width: 180, height: 180)
                Image(systemName: page.symbol)
                    .font(.system(size: 72, weight: .semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: isActive)
                // Emojis orbit and bob around the hero using a phase animator.
                ForEach(page.emojis.indices, id: \.self) { index in
                    FloatingEmoji(emoji: page.emojis[index], index: index)
                }
            }
            .frame(height: 280)
            .accessibilityHidden(true)

            VStack(spacing: Spacing.m) {
                Text(page.title)
                    .font(.rounded(.largeTitle, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(page.message)
                    .font(.rounded(.body))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Spacing.xl)
            Spacer(minLength: 0)
        }
    }
}

private struct FloatingEmoji: View {
    let emoji: String
    let index: Int

    var body: some View {
        let angle = Double(index) / 4 * 2 * .pi - .pi / 4
        Text(emoji)
            .font(.system(size: 40))
            .phaseAnimator([false, true]) { content, up in
                content
                    .offset(y: up ? -8 : 8)
                    .rotationEffect(.degrees(up ? 6 : -6))
            } animation: { _ in
                .easeInOut(duration: 1.4 + Double(index) * 0.2)
            }
            .offset(x: cos(angle) * 125, y: sin(angle) * 120)
    }
}

#Preview {
    OnboardingView {}
        .environment(AppServices.preview)
}
