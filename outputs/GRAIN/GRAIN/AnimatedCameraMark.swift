import SwiftUI

struct AnimatedCameraMark: View {
    let size: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? 0.12 : time.truncatingRemainder(dividingBy: 3.2) / 3.2
            let pulse = reduceMotion ? 0.5 : (sin(time * 3.4) + 1) / 2

            ZStack {
                Circle()
                    .fill(GrainTheme.paper)

                RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                    .fill(GrainTheme.black)
                    .frame(width: size * 0.67, height: size * 0.39)
                    .offset(y: size * 0.055)

                RoundedRectangle(cornerRadius: size * 0.05, style: .continuous)
                    .fill(GrainTheme.black)
                    .frame(width: size * 0.27, height: size * 0.16)
                    .offset(y: -size * 0.17)

                Circle()
                    .fill(GrainTheme.paper)
                    .frame(width: size * 0.33, height: size * 0.33)
                    .offset(y: size * 0.055)

                Circle()
                    .fill(GrainTheme.black)
                    .frame(width: size * 0.24, height: size * 0.24)
                    .offset(y: size * 0.055)

                Circle()
                    .trim(from: phase, to: phase + 0.47)
                    .stroke(
                        GrainTheme.accent,
                        style: StrokeStyle(lineWidth: max(1.5, size * 0.045), lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: size * 0.19, height: size * 0.19)
                    .offset(y: size * 0.055)

                Circle()
                    .fill(GrainTheme.accent)
                    .frame(width: max(2.5, size * 0.075), height: max(2.5, size * 0.075))
                    .scaleEffect(0.82 + pulse * 0.28)
                    .offset(x: size * 0.235, y: -size * 0.16)

                if size >= 72 {
                    HStack(spacing: size * 0.035) {
                        ForEach(0..<3, id: \.self) { index in
                            Capsule()
                                .fill(GrainTheme.black.opacity(0.22))
                                .frame(width: size * 0.09, height: max(1, size * 0.014))
                                .offset(y: CGFloat(index - 1) * size * 0.045)
                        }
                    }
                    .offset(x: -size * 0.42, y: size * 0.03)
                }
            }
            .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }
}
