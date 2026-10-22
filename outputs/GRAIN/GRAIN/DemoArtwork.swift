import SwiftUI

struct DemoArtwork: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x26343B), Color(hex: 0x7A5D52), Color(hex: 0xD28A61)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: 0xFFE3B3), Color(hex: 0xE9A56A).opacity(0.4), .clear],
                            center: .center,
                            startRadius: 2,
                            endRadius: w * 0.20
                        )
                    )
                    .frame(width: w * 0.42, height: w * 0.42)
                    .position(x: w * 0.68, y: h * 0.30)

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.58))
                    path.addCurve(
                        to: CGPoint(x: w, y: h * 0.50),
                        control1: CGPoint(x: w * 0.22, y: h * 0.35),
                        control2: CGPoint(x: w * 0.60, y: h * 0.57)
                    )
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x2F3A39), Color(hex: 0x151C1B)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                Path { path in
                    path.move(to: CGPoint(x: 0, y: h * 0.69))
                    path.addCurve(
                        to: CGPoint(x: w, y: h * 0.64),
                        control1: CGPoint(x: w * 0.34, y: h * 0.58),
                        control2: CGPoint(x: w * 0.62, y: h * 0.72)
                    )
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.addLine(to: CGPoint(x: 0, y: h))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x765543), Color(hex: 0x2D2925)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                Capsule()
                    .fill(Color(hex: 0xE4B781).opacity(0.23))
                    .frame(width: w * 0.5, height: 2)
                    .rotationEffect(.degrees(-2))
                    .position(x: w * 0.57, y: h * 0.66)

                Capsule()
                    .fill(Color(hex: 0xF2D2A6).opacity(0.18))
                    .frame(width: w * 0.32, height: 1.5)
                    .rotationEffect(.degrees(2))
                    .position(x: w * 0.33, y: h * 0.72)

                person(width: w, height: h)
                    .position(x: w * 0.36, y: h * 0.73)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.42)],
                    startPoint: .center,
                    endPoint: .bottom
                )
            }
            .overlay {
                GrainOverlay()
                    .blendMode(.softLight)
                    .opacity(0.58)
            }
            .clipped()
        }
        .aspectRatio(4 / 5, contentMode: .fit)
    }

    private func person(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Capsule()
                .fill(Color(hex: 0xA64230))
                .frame(width: width * 0.105, height: height * 0.17)
            Circle()
                .fill(Color(hex: 0x211E1A))
                .frame(width: width * 0.052, height: width * 0.052)
                .offset(y: -height * 0.105)
            Capsule()
                .fill(Color(hex: 0x1E1C19))
                .frame(width: width * 0.02, height: height * 0.105)
                .offset(x: -width * 0.028, y: height * 0.115)
            Capsule()
                .fill(Color(hex: 0x1E1C19))
                .frame(width: width * 0.02, height: height * 0.105)
                .offset(x: width * 0.028, y: height * 0.115)
        }
        .shadow(color: .black.opacity(0.34), radius: 12, y: 8)
    }
}

struct GrainOverlay: View {
    var body: some View {
        Canvas { context, size in
            var generator = SeededGenerator(seed: 419)
            for _ in 0..<1400 {
                let x = CGFloat.random(in: 0...size.width, using: &generator)
                let y = CGFloat.random(in: 0...size.height, using: &generator)
                let alpha = Double.random(in: 0.015...0.10, using: &generator)
                let diameter = Double.random(in: 0.35...1.4, using: &generator)
                let rect = CGRect(x: x, y: y, width: diameter, height: diameter)
                context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(alpha)))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
