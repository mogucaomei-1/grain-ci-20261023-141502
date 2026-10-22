import SwiftUI

enum GrainTheme {
    static let ink = Color(hex: 0x11110F)
    static let panel = Color(hex: 0x1A1A17)
    static let panelRaised = Color(hex: 0x23231F)
    static let paper = Color(hex: 0xF1E9DC)
    static let paperMuted = Color(hex: 0xA9A398)
    static let line = Color.white.opacity(0.10)
    static let accent = Color(hex: 0xD9774E)
    static let sage = Color(hex: 0x879682)
    static let red = Color(hex: 0xA94835)
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
            GrainTheme.ink
            RadialGradient(
                colors: [GrainTheme.accent.opacity(0.11), .clear],
                center: UnitPoint(x: 0.86, y: 0.04),
                startRadius: 0,
                endRadius: 360
            )
            LinearGradient(
                colors: [.clear, Color.black.opacity(0.32)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

struct EditorialHeader: View {
    let onImport: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(GrainTheme.paper)
                Circle()
                    .trim(from: 0.04, to: 0.53)
                    .stroke(GrainTheme.ink, style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                    .rotationEffect(.degrees(-34))
                    .padding(8)
                Circle()
                    .fill(GrainTheme.accent)
                    .frame(width: 7, height: 7)
                    .offset(x: 8, y: -7)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 0) {
                Text("GRAIN")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .tracking(2.8)
                    .foregroundStyle(GrainTheme.paper)
                Text("RAW FILM LAB")
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .tracking(2.2)
                    .foregroundStyle(GrainTheme.paperMuted)
            }

            Spacer()

            Button(action: onImport) {
                HStack(spacing: 7) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                    Text("导入 RAW")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(GrainTheme.ink)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(GrainTheme.paper, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

struct SectionEyebrow: View {
    let index: String
    let title: String
    var trailing: String?

    var body: some View {
        HStack(spacing: 9) {
            Text(index)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(GrainTheme.accent)
            Rectangle()
                .fill(GrainTheme.line)
                .frame(height: 1)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(GrainTheme.paperMuted)
                .fixedSize()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(GrainTheme.paperMuted.opacity(0.75))
                    .fixedSize()
            }
        }
    }
}

struct FilmSwatch: View {
    let profile: FilmProfile
    var selected = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: profile.uiPalette,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                Text(profile.shortName)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                    .padding(9)
            }
            .frame(width: 94, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(selected ? GrainTheme.paper : .clear, lineWidth: 1.5)
            }

            Text(profile.name)
                .font(.system(size: 11, weight: selected ? .semibold : .medium, design: .rounded))
                .foregroundStyle(selected ? GrainTheme.paper : GrainTheme.paperMuted)
                .lineLimit(1)
                .frame(width: 94, alignment: .leading)
        }
        .padding(5)
        .background(selected ? GrainTheme.panelRaised : .clear, in: RoundedRectangle(cornerRadius: 15))
    }
}

struct ParameterSlider: View {
    let label: String
    let symbol: String
    let valueText: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var onChange: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(GrainTheme.paperMuted)
                .frame(width: 18)

            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(GrainTheme.paperMuted)
                .frame(width: 38, alignment: .leading)

            Slider(value: $value, in: range, onEditingChanged: { editing in
                if !editing { onChange() }
            })
            .tint(GrainTheme.accent)

            Text(valueText)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(GrainTheme.paper)
                .frame(width: 46, alignment: .trailing)
        }
        .frame(height: 40)
    }
}

struct PillLabel: View {
    let text: String
    var accent = false

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(accent ? GrainTheme.ink : GrainTheme.paper)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(
                accent ? GrainTheme.accent : Color.black.opacity(0.48),
                in: Capsule()
            )
            .overlay {
                if !accent {
                    Capsule().stroke(Color.white.opacity(0.16), lineWidth: 0.7)
                }
            }
    }
}
