import SwiftUI
import UniformTypeIdentifiers

private enum GrainTab: String, CaseIterable {
    case develop
    case looks
    case export

    var title: String {
        switch self {
        case .develop: "编辑"
        case .looks: "胶片"
        case .export: "导出"
        }
    }

    var symbol: String {
        switch self {
        case .develop: "slider.horizontal.3"
        case .looks: "circle.hexagongrid"
        case .export: "arrow.up.right"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var selectedTab: GrainTab = .develop
    @State private var showImportSource = false
    @State private var showPhotoPicker = false
    @State private var showFileImporter = false

    var body: some View {
        ZStack {
            GrainBackground()
            VStack(spacing: 0) {
                EditorialHeader {
                    showImportSource = true
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 14)

                Group {
                    switch selectedTab {
                    case .develop:
                        DevelopView()
                    case .looks:
                        LooksView {
                            selectedTab = .develop
                        }
                    case .export:
                        ExportView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            GrainTabBar(selected: $selectedTab)
        }
        .confirmationDialog("导入 RAW", isPresented: $showImportSource, titleVisibility: .visible) {
            Button("从照片图库导入") { showPhotoPicker = true }
            Button("从文件导入") { showFileImporter = true }
            Button("取消", role: .cancel) {}
        } message: {
            Text("支持 Sony ARW，也可导入 HEIC、JPEG、DNG。")
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
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.rawImage, .image],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    editor.importPhoto(from: url)
                }
            case .failure(let error):
                editor.errorMessage = error.localizedDescription
            }
        }
        .sheet(item: $editor.exportResult) { result in
            ExportResultSheet(result: result)
        }
        .alert(
            "处理没有完成",
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
}

private struct GrainTabBar: View {
    @Binding var selected: GrainTab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(GrainTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.snappy(duration: 0.24)) {
                        selected = tab
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 12, weight: .semibold))
                        Text(tab.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(selected == tab ? GrainTheme.ink : GrainTheme.paperMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 42)
                    .background(
                        selected == tab ? GrainTheme.paper : Color.clear,
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.7)
        }
        .padding(.horizontal, 26)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }
}

private struct DevelopView: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                titleBlock
                EditorCanvas()

                HStack(spacing: 0) {
                    metadataCell(
                        value: editor.photo?.cameraLabel ?? "SONY A7R V",
                        label: "相机"
                    )
                    metadataDivider
                    metadataCell(
                        value: editor.photo?.megapixelsLabel ?? "61.0 MP",
                        label: "原始尺寸"
                    )
                    metadataDivider
                    metadataCell(
                        value: editor.photo?.fileSizeLabel ?? "ARW / DEMO",
                        label: "源文件"
                    )
                }
                .padding(.vertical, 12)
                .background(GrainTheme.panel, in: RoundedRectangle(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(GrainTheme.line, lineWidth: 0.7)
                }

                SectionEyebrow(index: "01", title: "Film Recipe", trailing: editor.selectedProfile.name)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FilmProfile.allCases) { profile in
                            Button {
                                editor.selectProfile(profile)
                            } label: {
                                FilmSwatch(
                                    profile: profile,
                                    selected: editor.selectedProfile == profile
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .contentMargins(.horizontal, 0, for: .scrollContent)

                VStack(spacing: 4) {
                    SectionEyebrow(index: "02", title: "Fine Tune")

                    ParameterSlider(
                        label: "强度",
                        symbol: "circle.lefthalf.filled",
                        valueText: "\(Int(editor.intensity * 100))",
                        value: Binding(
                            get: { editor.intensity * 100 },
                            set: { editor.intensity = $0 / 100 }
                        ),
                        range: 0...100,
                        onChange: editor.schedulePreview
                    )

                    ParameterSlider(
                        label: "曝光",
                        symbol: "sun.max",
                        valueText: String(format: "%+.1f", editor.settings.exposure),
                        value: $editor.settings.exposure,
                        range: -2...2,
                        onChange: editor.schedulePreview
                    )

                    ParameterSlider(
                        label: "色温",
                        symbol: "thermometer.medium",
                        valueText: "\(Int(editor.settings.temperature))K",
                        value: $editor.settings.temperature,
                        range: 3500...9000,
                        onChange: editor.schedulePreview
                    )

                    ParameterSlider(
                        label: "颗粒",
                        symbol: "circle.grid.cross",
                        valueText: "\(Int(editor.settings.grain * 100))",
                        value: Binding(
                            get: { editor.settings.grain * 100 },
                            set: { editor.settings.grain = $0 / 100 }
                        ),
                        range: 0...60,
                        onChange: editor.schedulePreview
                    )

                    HStack {
                        Text(editor.selectedProfile.descriptor)
                            .font(.system(size: 10, weight: .regular, design: .rounded))
                            .foregroundStyle(GrainTheme.paperMuted)
                        Spacer()
                        Button("恢复配方") {
                            editor.resetSelectedProfile()
                        }
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(GrainTheme.accent)
                    }
                    .padding(.top, 7)
                }
                .padding(14)
                .background(GrainTheme.panel, in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(GrainTheme.line, lineWidth: 0.7)
                }

                Text("所有调整均作用于 RAW 解码后的高精度管线。预览为屏幕尺寸，导出始终使用原始像素尺寸。")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(GrainTheme.paperMuted.opacity(0.72))
                    .lineSpacing(3)
                    .padding(.horizontal, 2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .scrollIndicators(.hidden)
        .overlay {
            if editor.isPreparing && editor.photo != nil {
                VStack(spacing: 10) {
                    ProgressView()
                        .tint(GrainTheme.paper)
                    Text("正在显影")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(GrainTheme.paper)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.black.opacity(0.72), in: Capsule())
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(editor.photo?.displayName ?? "暮色之后")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(GrainTheme.paper)
                    .lineLimit(1)
                Spacer()
                Text(editor.photo == nil ? "DEMO FRAME" : "RAW 01")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(GrainTheme.accent)
            }
            Text("把数字底片，洗成时间。")
                .font(.system(size: 11, weight: .regular, design: .rounded))
                .foregroundStyle(GrainTheme.paperMuted)
        }
    }

    private var metadataDivider: some View {
        Rectangle()
            .fill(GrainTheme.line)
            .frame(width: 1, height: 28)
    }

    private func metadataCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(GrainTheme.paper)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label)
                .font(.system(size: 9, weight: .regular, design: .rounded))
                .foregroundStyle(GrainTheme.paperMuted)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct EditorCanvas: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var comparePosition = 0.44

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = proxy.size.height
            let splitX = width * comparePosition

            ZStack {
                editedImage
                    .frame(width: width, height: height)
                    .clipped()

                originalImage
                    .frame(width: width, height: height)
                    .clipped()
                    .frame(width: splitX, alignment: .leading)
                    .clipped()

                Rectangle()
                    .fill(Color.white.opacity(0.84))
                    .frame(width: 1)
                    .position(x: splitX, y: height / 2)
                    .shadow(color: .black.opacity(0.35), radius: 4)

                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .stroke(Color.white.opacity(0.8), lineWidth: 0.8)
                    HStack(spacing: 1) {
                        Image(systemName: "chevron.left")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                }
                .frame(width: 32, height: 32)
                .position(x: splitX, y: height / 2)

                VStack {
                    HStack {
                        PillLabel(text: "RAW")
                        Spacer()
                        PillLabel(text: editor.selectedProfile.shortName, accent: true)
                    }
                    Spacer()
                    HStack {
                        Text("向左查看原片")
                        Spacer()
                        Text(editor.photo?.dimensionsLabel ?? "9504 × 6336")
                    }
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.84))
                }
                .padding(12)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        comparePosition = min(max(value.location.x / width, 0.08), 0.92)
                    }
            )
        }
        .aspectRatio(displayAspect, contentMode: .fit)
        .background(GrainTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                .allowsHitTesting(false)
        }
        .shadow(color: .black.opacity(0.28), radius: 28, y: 20)
    }

    private var displayAspect: CGFloat {
        guard let photo = editor.photo, photo.pixelHeight > 0 else {
            return 4 / 5
        }
        let ratio = CGFloat(photo.pixelWidth) / CGFloat(photo.pixelHeight)
        return min(max(ratio, 0.62), 1.38)
    }

    @ViewBuilder
    private var editedImage: some View {
        if let image = editor.editedPreview {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()
        } else {
            DemoArtwork()
                .saturation(editor.selectedProfile == .hp5 ? 0 : 0.90)
                .contrast(1.05)
                .overlay(Color(hex: 0xD59A68).opacity(0.04))
        }
    }

    @ViewBuilder
    private var originalImage: some View {
        if let image = editor.originalPreview {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()
        } else {
            DemoArtwork()
                .saturation(0.25)
                .contrast(0.94)
        }
    }
}

private struct LooksView: View {
    @EnvironmentObject private var editor: EditorViewModel
    let onReturnToEditor: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("胶片配方室")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(GrainTheme.paper)
                    Text("不是滤镜叠加，而是围绕宽容度、色相偏移与银盐颗粒建立的色彩配方。")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(GrainTheme.paperMuted)
                        .lineSpacing(3)
                }

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(FilmProfile.allCases) { profile in
                        Button {
                            editor.selectProfile(profile)
                            onReturnToEditor()
                        } label: {
                            LookCard(
                                profile: profile,
                                selected: editor.selectedProfile == profile
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                    Text("配方名称仅用于描述色彩取向，与胶片厂商无隶属或授权关系。")
                        .font(.system(size: 10, design: .rounded))
                        .lineSpacing(3)
                }
                .foregroundStyle(GrainTheme.paperMuted.opacity(0.78))
                .padding(.top, 2)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
    }
}

private struct LookCard: View {
    let profile: FilmProfile
    let selected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                LinearGradient(
                    colors: profile.uiPalette,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(profile.uiPalette.last?.opacity(0.4) ?? .clear)
                    .frame(width: 72)
                    .blur(radius: 12)
                    .offset(x: 40, y: -12)
                LinearGradient(colors: [.clear, .black.opacity(0.56)], startPoint: .top, endPoint: .bottom)
                Text(profile.shortName)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.3)
                    .foregroundStyle(.white)
                    .padding(12)
            }
            .frame(height: 144)
            .clipped()

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(profile.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(GrainTheme.paper)
                    Spacer()
                    if selected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(GrainTheme.accent)
                    }
                }
                Text(profile.descriptor)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(GrainTheme.paperMuted)
                    .lineLimit(1)
            }
            .padding(12)
        }
        .background(GrainTheme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(selected ? GrainTheme.accent : GrainTheme.line, lineWidth: selected ? 1.3 : 0.7)
        }
    }
}

private struct ExportView: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("最高规格")
                        .font(.system(size: 30, weight: .bold, design: .serif))
                        .foregroundStyle(GrainTheme.paper)
                    Text("默认锁定原始尺寸，以最高质量写入新的图片文件，不覆盖 RAW。")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(GrainTheme.paperMuted)
                        .lineSpacing(3)
                }

                VStack(spacing: 0) {
                    exportSpecRow(
                        icon: "aspectratio",
                        label: "输出尺寸",
                        value: editor.photo?.dimensionsLabel ?? "原始像素",
                        note: "ORIGINAL"
                    )
                    divider
                    exportSpecRow(
                        icon: "camera",
                        label: "源文件",
                        value: editor.photo.map {
                            $0.cameraModel.isEmpty ? $0.cameraLabel : $0.cameraModel
                        } ?? "等待导入 RAW",
                        note: editor.photo?.fileSizeLabel ?? "—"
                    )
                    divider
                    exportSpecRow(
                        icon: "circle.hexagongrid",
                        label: "当前配方",
                        value: editor.selectedProfile.name,
                        note: "\(Int(editor.intensity * 100))%"
                    )
                }
                .padding(.horizontal, 15)
                .background(GrainTheme.panel, in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(GrainTheme.line, lineWidth: 0.7)
                }

                SectionEyebrow(index: "01", title: "File Format", trailing: "质量 100%")
                HStack(spacing: 10) {
                    ForEach(ExportFormat.allCases) { format in
                        Button {
                            editor.exportOptions.format = format
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(format.title)
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    Spacer()
                                    Circle()
                                        .stroke(GrainTheme.paperMuted, lineWidth: 1)
                                        .overlay {
                                            if editor.exportOptions.format == format {
                                                Circle()
                                                    .fill(GrainTheme.accent)
                                                    .padding(3)
                                            }
                                        }
                                        .frame(width: 16, height: 16)
                                }
                                Text(format.subtitle)
                                    .font(.system(size: 9, design: .rounded))
                                    .foregroundStyle(GrainTheme.paperMuted)
                            }
                            .foregroundStyle(GrainTheme.paper)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(GrainTheme.panelRaised, in: RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        editor.exportOptions.format == format
                                            ? GrainTheme.accent.opacity(0.8)
                                            : GrainTheme.line,
                                        lineWidth: 0.8
                                    )
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                SectionEyebrow(index: "02", title: "Metadata")
                VStack(spacing: 0) {
                    metadataToggle(
                        title: "保留相机信息",
                        subtitle: "机身、镜头、快门与拍摄时间",
                        isOn: $editor.exportOptions.keepCameraMetadata,
                        symbol: "camera.aperture"
                    )
                    divider
                    metadataToggle(
                        title: "保留地址信息",
                        subtitle: editor.photo?.hasLocation == false
                            ? "源 RAW 中没有检测到 GPS"
                            : "经纬度将写入导出文件",
                        isOn: $editor.exportOptions.keepLocation,
                        symbol: "location"
                    )
                    .disabled(editor.photo?.hasLocation == false)
                    .opacity(editor.photo?.hasLocation == false ? 0.5 : 1)
                }
                .padding(.horizontal, 15)
                .background(GrainTheme.panel, in: RoundedRectangle(cornerRadius: 20))
                .overlay {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(GrainTheme.line, lineWidth: 0.7)
                }

                Button {
                    editor.export()
                } label: {
                    HStack(spacing: 10) {
                        if editor.isExporting {
                            ProgressView()
                                .tint(GrainTheme.ink)
                        } else {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(editor.isExporting ? "正在导出原尺寸…" : "导出最高规格")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                        Text(editor.exportOptions.format.title)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(GrainTheme.ink.opacity(0.56))
                    }
                    .foregroundStyle(GrainTheme.ink)
                    .padding(.horizontal, 18)
                    .frame(height: 54)
                    .background(GrainTheme.paper, in: RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)
                .disabled(!editor.canExport)
                .opacity(editor.canExport ? 1 : 0.4)

                Text("导出不会覆盖原始 RAW。关闭地址信息后，GPS 字段会从新文件元数据中移除。")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(GrainTheme.paperMuted.opacity(0.72))
                    .lineSpacing(3)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    private var divider: some View {
        Rectangle()
            .fill(GrainTheme.line)
            .frame(height: 1)
    }

    private func exportSpecRow(icon: String, label: String, value: String, note: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(GrainTheme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(GrainTheme.paperMuted)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(GrainTheme.paper)
                    .lineLimit(1)
            }
            Spacer()
            Text(note)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(GrainTheme.paperMuted)
        }
        .frame(height: 60)
    }

    private func metadataToggle(
        title: String,
        subtitle: String,
        isOn: Binding<Bool>,
        symbol: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(GrainTheme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(GrainTheme.paper)
                Text(subtitle)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundStyle(GrainTheme.paperMuted)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(GrainTheme.accent)
        }
        .frame(height: 64)
    }
}

private struct ExportResultSheet: View {
    let result: ExportResult
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            GrainTheme.ink.ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(GrainTheme.accent.opacity(0.14))
                        .frame(width: 72, height: 72)
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(GrainTheme.accent)
                }

                VStack(spacing: 6) {
                    Text("显影完成")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundStyle(GrainTheme.paper)
                    Text("已按原始像素尺寸输出最高质量文件")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(GrainTheme.paperMuted)
                }

                HStack(spacing: 24) {
                    resultStat(value: result.dimensions, label: "像素")
                    resultStat(value: result.format.title, label: "格式")
                    resultStat(value: "100%", label: "质量")
                }
                .padding(18)
                .background(GrainTheme.panel, in: RoundedRectangle(cornerRadius: 20))

                ShareLink(item: result.url) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("存储或分享")
                        Spacer()
                        Text(result.format.title)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(GrainTheme.ink.opacity(0.55))
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(GrainTheme.ink)
                    .padding(.horizontal, 18)
                    .frame(height: 52)
                    .background(GrainTheme.paper, in: RoundedRectangle(cornerRadius: 17))
                }

                Button("返回编辑") {
                    dismiss()
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(GrainTheme.paperMuted)
            }
            .padding(24)
        }
        .presentationDetents([.height(430)])
        .presentationDragIndicator(.visible)
    }

    private func resultStat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(GrainTheme.paper)
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(GrainTheme.paperMuted)
        }
    }
}
