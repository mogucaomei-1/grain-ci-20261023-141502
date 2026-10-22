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
        VStack(spacing: 7) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: profile.uiPalette,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [.clear, .black.opacity(0.42)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Text(profile.shortName)
                    .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(.white)
                    .padding(7)
            }
            .frame(width: 71, height: 49)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            Text(profile.name)
                .font(.system(size: 9.5, weight: selected ? .semibold : .regular, design: .rounded))
                .foregroundStyle(selected ? GrainTheme.paper : GrainTheme.muted)
                .lineLimit(1)
                .frame(width: 72)
        }
        .padding(4)
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
