import SwiftUI

struct RootView: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var showImportSource = false
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var showExportSheet = false

    var body: some View {
        ZStack {
            GrainBackground()

            VStack(spacing: 0) {
                MinimalTopBar(
                    hasPhoto: editor.photo != nil,
                    onBack: editor.returnHome,
                    onImport: { showImportSource = true },
                    onExport: {
                        editor.exportResult = nil
                        showExportSheet = true
                    }
                )

                if editor.photo == nil {
                    EmptyImportView(
                        onOpenPhotos: requestPhotoLibrary,
                        onOpenFiles: { showDocumentPicker = true }
                    )
                } else {
                    EditorWorkspace()
                }
            }
        }
        .confirmationDialog("导入照片", isPresented: $showImportSource, titleVisibility: .visible) {
            Button("从照片图库选择") { requestPhotoLibrary() }
            Button("从文件选择 Sony RAW") { showDocumentPicker = true }
            Button("取消", role: .cancel) {}
        } message: {
            Text("照片图库会自动获取 iCloud 中的原始 RAW；若系统只返回 JPEG，可改用文件导入。")
        }
        .fullScreenCover(isPresented: $showPhotoPicker) {
            PhotosRawImporter { url in
                showPhotoPicker = false
                editor.importPhoto(from: url)
            } onCancel: {
                showPhotoPicker = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentRawImporter { url in
                showDocumentPicker = false
                editor.importPhoto(from: url)
            } onCancel: {
                showDocumentPicker = false
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSettingsSheet()
                .environmentObject(editor)
                .presentationDetents([.height(470)])
                .presentationDragIndicator(.visible)
        }
        .alert(
            "无法打开照片",
            isPresented: Binding(
                get: { editor.errorMessage != nil },
                set: { if !$0 { editor.errorMessage = nil } }
            )
        ) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text(editor.errorMessage ?? "")
        }
    }

    private func requestPhotoLibrary() {
        Task {
            if await PhotoLibraryAccess.request() {
                showPhotoPicker = true
            } else {
                editor.errorMessage = "照片读取权限未开启。请前往“设置 → GRAIN → 照片”允许读取，才能从 iCloud 下载原始 RAW。"
            }
        }
    }
}

private struct MinimalTopBar: View {
    let hasPhoto: Bool
    let onBack: () -> Void
    let onImport: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                if hasPhoto {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 32, height: 38)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(GrainTheme.paper)
                }

                ZStack {
                    Circle().fill(GrainTheme.paper)
                    Circle()
                        .trim(from: 0.05, to: 0.52)
                        .stroke(GrainTheme.black, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                        .rotationEffect(.degrees(-34))
                        .padding(6)
                    Circle()
                        .fill(GrainTheme.accent)
                        .frame(width: 5, height: 5)
                        .offset(x: 6, y: -5)
                }
                .frame(width: 29, height: 29)

                VStack(alignment: .leading, spacing: 1) {
                    Text("GRAIN")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .tracking(2.1)
                    Text("RAW FILM LAB  1.1")
                        .font(.system(size: 6.5, weight: .semibold, design: .monospaced))
                        .tracking(1.3)
                        .foregroundStyle(GrainTheme.muted)
                }
            }

            Spacer()

            Button(action: onImport) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 38, height: 38)
                    .background(GrainTheme.raised, in: Circle())
            }
            .buttonStyle(.plain)

            Button(action: onExport) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(hasPhoto ? GrainTheme.black : GrainTheme.muted)
                    .frame(width: 38, height: 38)
                    .background(hasPhoto ? GrainTheme.paper : GrainTheme.raised, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!hasPhoto)
        }
        .foregroundStyle(GrainTheme.paper)
        .padding(.horizontal, 18)
        .frame(height: 54)
    }
}

private struct EmptyImportView: View {
    let onOpenPhotos: () -> Void
    let onOpenFiles: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                Circle()
                    .fill(GrainTheme.surface)
                    .frame(width: 116, height: 116)
                Circle()
                    .stroke(GrainTheme.line, lineWidth: 1)
                    .frame(width: 116, height: 116)
                Image(systemName: "camera.aperture")
                    .font(.system(size: 35, weight: .light))
                    .foregroundStyle(GrainTheme.paper)
            }
            .padding(.bottom, 24)

            Text("打开原始照片")
                .font(.system(size: 27, weight: .bold, design: .serif))
                .foregroundStyle(GrainTheme.paper)
                .padding(.bottom, 7)

            Text("从“文件”选择 Sony ARW，保留完整 RAW 与元数据")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(GrainTheme.muted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)

            Button(action: onOpenPhotos) {
                HStack(spacing: 9) {
                    Image(systemName: "photo.on.rectangle")
                    Text("从照片图库选择")
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(GrainTheme.black.opacity(0.45))
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(GrainTheme.black)
                .padding(.horizontal, 17)
                .frame(height: 52)
                .background(GrainTheme.paper, in: RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 34)
            .padding(.top, 32)

            Button(action: onOpenFiles) {
                HStack(spacing: 8) {
                    Image(systemName: "folder")
                    Text("从文件导入 RAW")
                }
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(GrainTheme.paper)
                .padding(.horizontal, 16)
                .frame(height: 42)
                .background(GrainTheme.raised, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 12)

            Spacer()

            Text("ARW  ·  SRF  ·  SR2  ·  DNG")
                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                .tracking(1.8)
                .foregroundStyle(GrainTheme.muted.opacity(0.55))
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct EditorWorkspace: View {
    var body: some View {
        VStack(spacing: 0) {
            PhotoEditorCanvas()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            FilmPresetBar()
                .frame(height: 100)

            AdjustPanel()
                .frame(height: 146)
        }
    }
}

private struct PhotoEditorCanvas: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var showOriginal = false

    var body: some View {
        GeometryReader { proxy in
            let imageHeight = min(proxy.size.height, proxy.size.width / imageAspect)

            ZStack {
                Color.black

                ZStack {
                    if showOriginal, let original = editor.originalPreview {
                        Image(decorative: original, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .transition(.opacity)
                    } else if let edited = editor.editedPreview {
                        Image(decorative: edited, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .transition(.opacity)
                    } else {
                        ProgressView()
                            .tint(GrainTheme.paper)
                    }

                    VStack {
                        HStack {
                            Label("RAW", systemImage: "circle.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(GrainTheme.paper)
                                .padding(.horizontal, 9)
                                .frame(height: 24)
                                .background(.black.opacity(0.52), in: Capsule())

                            Spacer()

                            if editor.isPreparing {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(GrainTheme.paper)
                                    .padding(8)
                                    .background(.black.opacity(0.46), in: Circle())
                            }
                        }

                        Spacer()

                        HStack(alignment: .bottom) {
                            Text(showOriginal ? "原片" : editor.selectedProfile.name)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(GrainTheme.paper)
                                .padding(.horizontal, 10)
                                .frame(height: 27)
                                .background(.black.opacity(0.48), in: Capsule())

                            Spacer()

                            Text("按住看原片")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundStyle(GrainTheme.paper)
                                .padding(.horizontal, 11)
                                .frame(height: 29)
                                .background(.black.opacity(0.52), in: Capsule())
                                .contentShape(Capsule())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { _ in
                                            withAnimation(.easeOut(duration: 0.12)) {
                                                showOriginal = true
                                            }
                                        }
                                        .onEnded { _ in
                                            withAnimation(.easeOut(duration: 0.16)) {
                                                showOriginal = false
                                            }
                                        }
                                )
                        }
                    }
                    .padding(13)
                }
                .frame(width: proxy.size.width, height: imageHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var imageAspect: CGFloat {
        guard let photo = editor.photo, photo.pixelWidth > 0, photo.pixelHeight > 0 else {
            return 3 / 2
        }
        return CGFloat(photo.pixelWidth) / CGFloat(photo.pixelHeight)
    }
}

private struct FilmPresetBar: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("FILM")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(GrainTheme.muted)
                Text(editor.selectedProfile.name)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(GrainTheme.paper)
                Spacer()
                Button {
                    editor.recommendLook()
                } label: {
                    HStack(spacing: 4) {
                        if editor.isRecommending {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(GrainTheme.accent)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("推荐")
                    }
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(GrainTheme.accent)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(GrainTheme.accent.opacity(0.10), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(editor.isRecommending)

                Button {
                    editor.resetSelectedProfile()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(GrainTheme.muted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 18)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(FilmProfile.allCases) { profile in
                        Button {
                            editor.selectProfile(profile)
                        } label: {
                            FilmPresetChip(
                                profile: profile,
                                selected: editor.selectedProfile == profile
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
    }
}

private enum AdjustCategory: String, CaseIterable, Identifiable {
    case light
    case color
    case effects

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "光线"
        case .color: "颜色"
        case .effects: "效果"
        }
    }
}

private enum AdjustTool: String, CaseIterable, Identifiable {
    case intensity
    case exposure
    case contrast
    case highlights
    case shadows
    case whites
    case blacks
    case temperature
    case tint
    case vibrance
    case saturation
    case clarity
    case sharpness
    case fade
    case grain
    case vignette

    var id: String { rawValue }

    var title: String {
        switch self {
        case .intensity: "强度"
        case .exposure: "曝光"
        case .contrast: "对比"
        case .highlights: "高光"
        case .shadows: "阴影"
        case .whites: "白色"
        case .blacks: "黑色"
        case .temperature: "色温"
        case .tint: "色调"
        case .vibrance: "自然饱和"
        case .saturation: "饱和"
        case .clarity: "清晰度"
        case .sharpness: "锐化"
        case .fade: "褪色"
        case .grain: "颗粒"
        case .vignette: "暗角"
        }
    }

    var category: AdjustCategory {
        switch self {
        case .exposure, .contrast, .highlights, .shadows, .whites, .blacks:
            .light
        case .temperature, .tint, .vibrance, .saturation:
            .color
        case .intensity, .clarity, .sharpness, .fade, .grain, .vignette:
            .effects
        }
    }
}

private struct AdjustPanel: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var selectedCategory: AdjustCategory = .light
    @State private var selectedTool: AdjustTool = .exposure

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 22) {
                ForEach(AdjustCategory.allCases) { category in
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            selectedCategory = category
                            selectedTool = tools(for: category).first ?? .exposure
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(category.title)
                                .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(
                                    selectedCategory == category ? GrainTheme.paper : GrainTheme.muted
                                )
                            Capsule()
                                .fill(selectedCategory == category ? GrainTheme.accent : .clear)
                                .frame(width: 18, height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(tools(for: selectedCategory)) { tool in
                        Button {
                            selectedTool = tool
                        } label: {
                            Text(tool.title)
                                .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                .foregroundStyle(
                                    selectedTool == tool ? GrainTheme.black : GrainTheme.muted
                                )
                                .padding(.horizontal, 13)
                                .frame(height: 28)
                                .background(
                                    selectedTool == tool ? GrainTheme.paper : GrainTheme.raised,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 12) {
                Slider(value: activeBinding, in: activeRange)
                    .tint(GrainTheme.accent)

                Text(activeValueText)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(GrainTheme.paper)
                    .frame(width: 52, alignment: .trailing)
            }
            .frame(height: 31)
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(GrainTheme.surface)
        .overlay(alignment: .top) {
            Rectangle().fill(GrainTheme.line).frame(height: 1)
        }
    }

    private var activeRange: ClosedRange<Double> {
        switch selectedTool {
        case .intensity: 0...100
        case .exposure: -2...2
        case .temperature: 3500...9000
        case .grain, .vignette, .fade, .sharpness: 0...100
        default: -100...100
        }
    }

    private var activeBinding: Binding<Double> {
        Binding(
            get: { value(for: selectedTool) },
            set: {
                setValue($0, for: selectedTool)
                editor.schedulePreview()
            }
        )
    }

    private var activeValueText: String {
        switch selectedTool {
        case .intensity:
            "\(Int(editor.intensity * 100))"
        case .exposure:
            String(format: "%+.1f", editor.settings.exposure)
        case .temperature:
            "\(Int(editor.settings.temperature))K"
        default:
            String(format: "%+.0f", value(for: selectedTool))
        }
    }

    private func tools(for category: AdjustCategory) -> [AdjustTool] {
        AdjustTool.allCases.filter { $0.category == category }
    }

    private func value(for tool: AdjustTool) -> Double {
        switch tool {
        case .intensity: editor.intensity * 100
        case .exposure: editor.settings.exposure
        case .contrast: editor.settings.contrast
        case .highlights: editor.settings.highlights
        case .shadows: editor.settings.shadows
        case .whites: editor.settings.whites
        case .blacks: editor.settings.blacks
        case .temperature: editor.settings.temperature
        case .tint: editor.settings.tint
        case .vibrance: editor.settings.vibrance
        case .saturation: editor.settings.saturation
        case .clarity: editor.settings.clarity
        case .sharpness: editor.settings.sharpness
        case .fade: editor.settings.fade
        case .grain: editor.settings.grain
        case .vignette: editor.settings.vignette
        }
    }

    private func setValue(_ value: Double, for tool: AdjustTool) {
        switch tool {
        case .intensity: editor.intensity = value / 100
        case .exposure: editor.settings.exposure = value
        case .contrast: editor.settings.contrast = value
        case .highlights: editor.settings.highlights = value
        case .shadows: editor.settings.shadows = value
        case .whites: editor.settings.whites = value
        case .blacks: editor.settings.blacks = value
        case .temperature: editor.settings.temperature = value
        case .tint: editor.settings.tint = value
        case .vibrance: editor.settings.vibrance = value
        case .saturation: editor.settings.saturation = value
        case .clarity: editor.settings.clarity = value
        case .sharpness: editor.settings.sharpness = value
        case .fade: editor.settings.fade = value
        case .grain: editor.settings.grain = value
        case .vignette: editor.settings.vignette = value
        }
    }
}

private struct ExportSettingsSheet: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss

    @ViewBuilder
    var body: some View {
        if let result = editor.exportResult {
            ExportResultSheet(result: result)
        } else {
            ZStack {
                GrainTheme.black.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("导出")
                            .font(.system(size: 25, weight: .bold, design: .serif))
                            .foregroundStyle(GrainTheme.paper)
                        Text("原始尺寸 · 最高质量")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(GrainTheme.muted)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .frame(width: 30, height: 30)
                            .background(GrainTheme.raised, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(GrainTheme.paper)
                }

                HStack(spacing: 0) {
                    ExportFact(value: editor.photo?.dimensionsLabel ?? "—", label: "像素")
                    Divider().overlay(GrainTheme.line).frame(height: 30)
                    ExportFact(value: editor.selectedProfile.shortName, label: "胶片")
                    Divider().overlay(GrainTheme.line).frame(height: 30)
                    ExportFact(value: editor.exportOptions.format.title, label: "格式")
                }
                .padding(.vertical, 12)
                .background(GrainTheme.surface, in: RoundedRectangle(cornerRadius: 16))

                HStack(spacing: 9) {
                    ForEach(ExportFormat.allCases) { format in
                        Button {
                            editor.exportOptions.format = format
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(format.title)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                Text(format.subtitle)
                                    .font(.system(size: 8.5, design: .rounded))
                                    .foregroundStyle(GrainTheme.muted)
                            }
                            .foregroundStyle(GrainTheme.paper)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GrainTheme.surface, in: RoundedRectangle(cornerRadius: 14))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(
                                        editor.exportOptions.format == format
                                            ? GrainTheme.accent
                                            : GrainTheme.line,
                                        lineWidth: 1
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Toggle(isOn: $editor.exportOptions.keepLocation) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("保留地址信息")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Text(editor.photo?.hasLocation == true ? "GPS 将写入导出文件" : "源文件未检测到 GPS")
                            .font(.system(size: 8.5, design: .rounded))
                            .foregroundStyle(GrainTheme.muted)
                    }
                }
                .tint(GrainTheme.accent)
                .disabled(editor.photo?.hasLocation != true)

                Toggle(isOn: $editor.exportOptions.keepCameraMetadata) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("保留相机信息")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Text("机身、镜头、快门与拍摄时间")
                            .font(.system(size: 8.5, design: .rounded))
                            .foregroundStyle(GrainTheme.muted)
                    }
                }
                .tint(GrainTheme.accent)

                Button {
                    editor.export()
                } label: {
                    HStack(spacing: 9) {
                        if editor.isExporting {
                            ProgressView().tint(GrainTheme.black)
                        } else {
                            Image(systemName: "arrow.up")
                        }
                        Text(editor.isExporting ? "正在导出…" : "导出原始尺寸")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        Text(editor.exportOptions.format.title)
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(GrainTheme.black.opacity(0.48))
                    }
                    .foregroundStyle(GrainTheme.black)
                    .padding(.horizontal, 16)
                    .frame(height: 51)
                    .background(GrainTheme.paper, in: RoundedRectangle(cornerRadius: 15))
                }
                .buttonStyle(.plain)
                .disabled(!editor.canExport)
                .opacity(editor.canExport ? 1 : 0.42)

                    Spacer(minLength: 0)
                }
                .padding(20)
            }
        }
    }
}

private struct ExportFact: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(GrainTheme.paper)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(label)
                .font(.system(size: 8, design: .rounded))
                .foregroundStyle(GrainTheme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExportResultSheet: View {
    let result: ExportResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GrainTheme.black.ignoresSafeArea()
            VStack(spacing: 17) {
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(GrainTheme.accent)
                    .frame(width: 62, height: 62)
                    .background(GrainTheme.accent.opacity(0.12), in: Circle())

                VStack(spacing: 4) {
                    Text("导出完成")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                    Text("\(result.dimensions) · \(result.format.title) · 100%")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(GrainTheme.muted)
                }

                ShareLink(item: result.url) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("存储或分享")
                        Spacer()
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(GrainTheme.black)
                    .padding(.horizontal, 17)
                    .frame(height: 50)
                    .background(GrainTheme.paper, in: RoundedRectangle(cornerRadius: 15))
                }

                Button("返回编辑") { dismiss() }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(GrainTheme.muted)
            }
            .padding(22)
        }
    }
}
