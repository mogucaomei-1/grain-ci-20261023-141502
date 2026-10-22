import SwiftUI

struct AnimatedCameraMark: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? 0.08 : time.truncatingRemainder(dividingBy: 2.8) / 2.8
            let pulse = reduceMotion ? 0.62 : (sin(time * 3.8) + 1) / 2

            ZStack {
                if size >= 68 {
                    motionLines
                        .opacity(0.45 + pulse * 0.35)
                }

                RoundedRectangle(cornerRadius: size * 0.085, style: .continuous)
                    .fill(GrainTheme.paper)
                    .frame(width: size * 0.26, height: size * 0.15)
                    .offset(y: -size * 0.26)

                RoundedRectangle(cornerRadius: size * 0.085, style: .continuous)
                    .fill(GrainTheme.paper)
                    .frame(width: size * 0.72, height: size * 0.43)
                    .offset(y: size * 0.09)

                RoundedRectangle(cornerRadius: size * 0.035, style: .continuous)
                    .fill(GrainTheme.paper)
                    .frame(width: size * 0.12, height: size * 0.045)
                    .offset(x: -size * 0.24, y: -size * 0.14)

                Circle()
                    .fill(GrainTheme.black)
                    .frame(width: size * 0.42, height: size * 0.42)
                    .offset(x: -size * 0.02, y: size * 0.09)

                Circle()
                    .fill(Color(hex: 0x23231F))
                    .frame(width: size * 0.31, height: size * 0.31)
                    .offset(x: -size * 0.02, y: size * 0.09)

                Circle()
                    .trim(from: phase, to: phase + 0.34)
                    .stroke(
                        Color(hex: 0x43848A),
                        style: StrokeStyle(lineWidth: max(1.4, size * 0.037), lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size * 0.265, height: size * 0.265)
                    .offset(x: -size * 0.02, y: size * 0.09)

                Circle()
                    .trim(from: phase + 0.43, to: phase + 0.82)
                    .stroke(
                        GrainTheme.accent,
                        style: StrokeStyle(lineWidth: max(1.4, size * 0.037), lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size * 0.265, height: size * 0.265)
                    .offset(x: -size * 0.02, y: size * 0.09)

                Circle()
                    .fill(GrainTheme.paper.opacity(0.82))
                    .frame(width: max(2, size * 0.047), height: max(2, size * 0.047))
                    .offset(x: -size * 0.06, y: size * 0.045)

                Circle()
                    .fill(GrainTheme.accent)
                    .frame(width: max(2.5, size * 0.075), height: max(2.5, size * 0.075))
                    .scaleEffect(0.86 + pulse * 0.22)
                    .offset(x: size * 0.205, y: -size * 0.07)

                if size >= 68 {
                    VStack(spacing: size * 0.035) {
                        ForEach(0..<3, id: \.self) { _ in
                            Capsule()
                                .fill(GrainTheme.black.opacity(0.28))
                                .frame(width: size * 0.07, height: max(1, size * 0.012))
                        }
                    }
                    .offset(x: -size * 0.27, y: size * 0.09)
                }
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }

    private var motionLines: some View {
        VStack(alignment: .trailing, spacing: size * 0.05) {
            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(GrainTheme.paper.opacity(0.24))
                    .frame(
                        width: size * (0.16 - CGFloat(index) * 0.025),
                        height: max(1, size * 0.012)
                    )
            }
        }
        .offset(x: -size * 0.40, y: -size * 0.02)
    }
}
