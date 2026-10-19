import SwiftUI
import FreshKeepCore

/// Custom component: an animated ring that empties as food gets closer to expiry.
///
/// The ring colour follows the freshness level, it animates in on appear and
/// when the value changes, and it scales with Dynamic Type through `@ScaledMetric`.
struct FreshnessRing: View {
    let freshness: Freshness
    var size: CGFloat = 56
    var lineWidth: CGFloat = 6
    var showsLabel = true

    @ScaledMetric private var scale: CGFloat = 1
    @State private var animatedFraction: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var color: Color { .freshness(freshness.level) }

    var body: some View {
        let side = size * min(scale, 1.6)
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: animatedFraction)
                .stroke(color.gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if showsLabel {
                VStack(spacing: -2) {
                    Text(daysText)
                        .font(.system(size: side * 0.32, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                    Text(unitText)
                        .font(.system(size: side * 0.16, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .minimumScaleFactor(0.5)
            }
        }
        .frame(width: side, height: side)
        .onAppear { animate(to: freshness.remainingFraction) }
        .onChange(of: freshness.remainingFraction) { _, newValue in animate(to: newValue) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Freshness")
        .accessibilityValue("\(freshness.level.title), \(freshness.summary)")
    }

    private var daysText: String {
        freshness.daysLeft < 0 ? "!" : "\(freshness.daysLeft)"
    }

    private var unitText: String {
        switch freshness.daysLeft {
        case ..<0: "expired"
        case 1: "day"
        default: "days"
        }
    }

    private func animate(to value: Double) {
        // A tiny minimum keeps a visible dot for items that expire today.
        let target = max(value, freshness.daysLeft >= 0 ? 0.04 : 0)
        if reduceMotion {
            animatedFraction = target
        } else {
            withAnimation(.easeOut(duration: 0.9)) { animatedFraction = target }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        FreshnessRing(freshness: .init(level: .fresh, daysLeft: 9, remainingFraction: 0.8))
        FreshnessRing(freshness: .init(level: .useSoon, daysLeft: 2, remainingFraction: 0.3))
        FreshnessRing(freshness: .init(level: .expiresToday, daysLeft: 0, remainingFraction: 0.05))
        FreshnessRing(freshness: .init(level: .expired, daysLeft: -2, remainingFraction: 0))
    }
    .padding()
}
