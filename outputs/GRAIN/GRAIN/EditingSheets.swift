import SwiftUI
import UIKit

struct TextOverlayEditorView: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    let overlayID: UUID
    @State private var draft = PhotoTextOverlay()
    @State private var hasLoaded = false

    var body: some View {
        ZStack {
            GrainTheme.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    Text("添加文字")
                        .font(.system(size: 23, weight: .bold, design: .serif))
                        .foregroundStyle(GrainTheme.paper)
                    Spacer()
                    Button {
                        editor.deleteTextOverlay(id: overlayID)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(GrainTheme.muted)
                    }
                    .buttonStyle(.plain)
                    Button {
                        editor.updateTextOverlay(draft)
                        dismiss()
                    } label: {
                        Text("完成")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(GrainTheme.black)
                            .padding(.horizontal, 13)
                            .frame(height: 32)
                            .background(GrainTheme.paper, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }

                TextEditor(text: $draft.text)
                    .font(.system(size: 18, weight: .medium, design: .rounded))
                    .foregroundStyle(GrainTheme.paper)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(height: 105)
                    .background(GrainTheme.surface, in: RoundedRectangle(cornerRadius: 15))
                    .overlay {
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(GrainTheme.line, lineWidth: 1)
                    }

                HStack(spacing: 8) {
                    ForEach(PhotoTextFont.allCases) { font in
                        Button {
                            draft.font = font
                        } label: {
                            Text(font.title)
                                .font(font.swiftUIFont(size: 13))
                                .foregroundStyle(draft.font == font ? GrainTheme.black : GrainTheme.paper)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(
                                    draft.font == font ? GrainTheme.paper : GrainTheme.raised,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Text("字号")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(GrainTheme.muted)
                    Slider(
                        value: $draft.fontSize,
                        in: 0.025...0.18
                    )
                    .tint(GrainTheme.accent)
                    Text("\(Int(draft.fontSize * 100))")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(GrainTheme.paper)
                        .frame(width: 30)
                }

                HStack(spacing: 10) {
                    Text("颜色")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(GrainTheme.muted)
                    ForEach(Array(colorOptions.enumerated()), id: \.offset) { _, color in
                        Button {
                            applyColor(color)
                        } label: {
                            Circle()
                                .fill(color)
                                .frame(width: 23, height: 23)
                                .overlay {
                                    Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.7)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    ColorPicker(
                        "",
                        selection: Binding(
                            get: { Color(red: draft.red, green: draft.green, blue: draft.blue, opacity: draft.alpha) },
                            set: { applyColor($0) }
                        ),
                        supportsOpacity: true
                    )
                    .labelsHidden()
                }

                Text("支持 Emoji。文字可以直接在照片上拖动位置。")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(GrainTheme.muted)
            }
            .padding(20)
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            if let overlay = editor.textOverlays.first(where: { $0.id == overlayID }) {
                draft = overlay
            }
        }
    }

    private var colorOptions: [Color] {
        [
            GrainTheme.paper,
            .black,
            GrainTheme.accent,
            .red,
            .yellow,
            .blue,
            .green
        ]
    }

    private func applyColor(_ color: Color) {
        let uiColor = UIColor(color)
        var red: CGFloat = 1
        var green: CGFloat = 1
        var blue: CGFloat = 1
        var alpha: CGFloat = 1
        if uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            draft.red = red
            draft.green = green
            draft.blue = blue
            draft.alpha = alpha
        }
    }
}

extension PhotoTextFont {
    func swiftUIFont(size: CGFloat) -> Font {
        switch self {
        case .rounded: .system(size: size, weight: .semibold, design: .rounded)
        case .serif: .system(size: size, weight: .semibold, design: .serif)
        case .monospaced: .system(size: size, weight: .semibold, design: .monospaced)
        }
    }
}

struct ImageInfoSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GrainTheme.black.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("图片信息")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 30, height: 30)
                            .background(GrainTheme.raised, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 16)

                if let photo = editor.photo {
                    ScrollView {
                        VStack(spacing: 0) {
                            infoRow("文件名", photo.displayName)
                            infoRow("图片尺寸", photo.dimensionsLabel)
                            infoRow("像素", photo.megapixelsLabel)
                            infoRow("文件大小", photo.fileSizeLabel)
                            infoRow("机型", photo.cameraLabel.isEmpty ? "未记录" : photo.cameraLabel)
                            infoRow("镜头", photo.lensModel.isEmpty ? "未记录" : photo.lensModel)
                            infoRow("拍摄时间", formattedDate(photo.capturedAt))
                            infoRow("位置", locationText(photo), isLast: true)
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .padding(20)
        }
    }

    private func infoRow(_ title: String, _ value: String, isLast: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(GrainTheme.muted)
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(GrainTheme.paper)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
            if !isLast {
                EmptyView()
            }
        }
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(GrainTheme.line).frame(height: 1)
            }
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date else { return "未记录" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 HH:mm:ss"
        return formatter.string(from: date)
    }

    private func locationText(_ photo: PhotoAsset) -> String {
        guard let latitude = photo.latitude, let longitude = photo.longitude else {
            return "未记录"
        }
        return String(format: "%.6f, %.6f", latitude, longitude)
    }
}
