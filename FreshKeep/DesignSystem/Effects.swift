import SwiftUI

// MARK: - Viewfinder

/// Custom shape: four rounded corner brackets, like a camera viewfinder.
struct ViewfinderShape: Shape {
    var cornerLength: CGFloat = 34
    var radius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let l = min(cornerLength, rect.width / 3, rect.height / 3)
        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        // Top-right
        path.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        return path
    }
}

/// Animated scan line that sweeps over a photo while Vision is working.
struct ScanningOverlay: View {
    var isScanning: Bool
    @State private var sweep = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ViewfinderShape()
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .shadow(color: .black.opacity(0.3), radius: 4)
                    .padding(Spacing.l)
                    .scaleEffect(isScanning && !reduceMotion ? 0.96 : 1)
                    .animation(isScanning ? .easeInOut(duration: 0.8).repeatForever() : .default, value: isScanning)

                if isScanning {
                    LinearGradient(colors: [.clear, Color.brand.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 70)
                        .overlay(Rectangle().fill(Color.brand).frame(height: 2))
                        .offset(y: sweep ? proxy.size.height / 2 - 40 : -proxy.size.height / 2 + 40)
                        .padding(.horizontal, Spacing.xl)
                        .onAppear {
                            sweep = false
                            guard !reduceMotion else { return }
                            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) { sweep = true }
                        }
                        .transition(.opacity)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Confetti

/// Celebration burst shown when food is rescued (marked as eaten).
/// Uses `keyframeAnimator` so every particle follows its own path.
struct ConfettiBurst: View {
    /// Change this value to fire a new burst.
    var trigger: Int
    private let particles = (0..<18).map { ConfettiParticle(index: $0) }

    var body: some View {
        ZStack {
            ForEach(particles) { particle in
                Text(particle.symbol)
                    .font(.title2)
                    .keyframeAnimator(initialValue: ConfettiFrame(), trigger: trigger) { content, frame in
                        content
                            .offset(x: frame.x, y: frame.y)
                            .rotationEffect(.degrees(frame.rotation))
                            .opacity(frame.opacity)
                            .scaleEffect(frame.scale)
                    } keyframes: { _ in
                        KeyframeTrack(\.x) {
                            LinearKeyframe(0, duration: 0.01)
                            CubicKeyframe(particle.dx, duration: 1.1)
                        }
                        KeyframeTrack(\.y) {
                            LinearKeyframe(0, duration: 0.01)
                            CubicKeyframe(particle.dy, duration: 0.45)
                            CubicKeyframe(particle.dy + 220, duration: 0.75)
                        }
                        KeyframeTrack(\.rotation) {
                            LinearKeyframe(particle.spin, duration: 1.2)
                        }
                        KeyframeTrack(\.scale) {
                            SpringKeyframe(1.2, duration: 0.3)
                            LinearKeyframe(0.8, duration: 0.9)
                        }
                        KeyframeTrack(\.opacity) {
                            LinearKeyframe(1, duration: 0.01)
                            LinearKeyframe(1, duration: 0.8)
                            LinearKeyframe(0, duration: 0.4)
                        }
                    }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct ConfettiFrame {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var rotation: Double = 0
    var scale: CGFloat = 0.2
    var opacity: Double = 0
}

private struct ConfettiParticle: Identifiable {
    let id: Int
    let dx: CGFloat
    let dy: CGFloat
    let spin: Double
    let symbol: String

    init(index: Int) {
        id = index
        let angle = Double(index) / 18 * 2 * .pi
        let distance = CGFloat(90 + (index * 37) % 70)
        dx = CGFloat(cos(angle)) * distance
        dy = CGFloat(sin(angle)) * distance - 80
        spin = Double((index * 53) % 360) - 180
        symbol = ["🍃", "✨", "🥕", "🍋", "💚", "🍓"][index % 6]
    }
}

// MARK: - Thumbnail

/// Photo thumbnail if the item has one, otherwise a tinted emoji tile.
struct ItemThumbnail: View {
    let item: PantryItem
    var size: CGFloat = 52

    @ScaledMetric private var scale: CGFloat = 1

    var body: some View {
        let side = size * min(scale, 1.5)
        Group {
            if let data = item.photoData,
               let image = ImagePipeline.thumbnail(for: item.id.uuidString, data: data, maxPixelSize: side * 3) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(item.emoji)
                    .font(.system(size: side * 0.55))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.freshness(item.freshness().level).opacity(0.15))
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: side * 0.28, style: .continuous))
        .accessibilityHidden(true)
    }
}
