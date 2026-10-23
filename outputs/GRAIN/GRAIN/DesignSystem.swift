import SwiftUI

enum GrainTheme {
    static let black = Color(hex: 0x070706)
    static let surface = Color(hex: 0x131311)
    static let raised = Color(hex: 0x1D1D1A)
    static let paper = Color(hex: 0xF4EDE1)
    static let muted = Color(hex: 0x8E8B84)
    static let line = Color.white.opacity(0.09)
    static let accent = Color(hex: 0xD9774E)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension FilmProfile {
    var uiPalette: [Color] {
        palette.map { Color(hex: $0) }
    }
}

struct GrainBackground: View {
    var body: some View {
        ZStack {
            GrainTheme.black
            RadialGradient(
                colors: [GrainTheme.accent.opacity(0.07), .clear],
                center: UnitPoint(x: 0.82, y: 0.02),
                startRadius: 0,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

struct FilmPresetChip: View {
    let profile: FilmProfile
    let selected: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: profile.uiPalette,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.52)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                FilmCameraGlyph(palette: profile.uiPalette)
                    .frame(width: 62, height: 39)
                    .offset(x: 14, y: -7)
                Text(profile.shortName)
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(.white)
                    .padding(7)
            }
            .frame(width: 92, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(profile.name)
                .font(.system(size: 9, weight: selected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(selected ? GrainTheme.paper : GrainTheme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(width: 96, height: 25, alignment: .top)
        }
        .padding(5)
        .background(
            selected ? GrainTheme.raised : Color.clear,
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(selected ? GrainTheme.accent.opacity(0.86) : .clear, lineWidth: 1)
        }
    }
}

private struct FilmCameraGlyph: View {
    let palette: [Color]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.black.opacity(0.34))
                .frame(width: 58, height: 30)
                .offset(y: 4)

            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(GrainTheme.paper)
                .frame(width: 58, height: 30)
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(GrainTheme.paper)
                        .frame(width: 18, height: 7)
                        .offset(x: 9, y: -5)
                }

            Circle()
                .fill(Color.black.opacity(0.82))
                .frame(width: 24, height: 24)
                .overlay {
                    Circle()
                        .trim(from: 0.08, to: 0.84)
                        .stroke(
                            AngularGradient(
                                colors: palette + [palette.first ?? GrainTheme.accent],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .padding(3)
                }

            Circle()
                .fill(GrainTheme.accent)
                .frame(width: 5, height: 5)
                .offset(x: 21, y: -7)
        }
        .shadow(color: .black.opacity(0.24), radius: 3, y: 2)
    }
}
