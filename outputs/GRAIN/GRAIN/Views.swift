import Photos
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var photoLibrary = PhotoLibraryViewModel()
    @AppStorage("showHistogram") private var showHistogram = true
    @State private var showDocumentPicker = false
    @State private var showExportSheet = false
    @State private var showInfoSheet = false
    @State private var showSettings = false

    var body: some View {
        ZStack {
            GrainBackground()

            NavigationStack {
                VStack(spacing: 0) {
                    MinimalTopBar(
                        hasPhoto: false,
                        onFiles: { showDocumentPicker = true },
                        onInfo: { showInfoSheet = true },
                        onSettings: { showSettings = true },
                        histogramVisible: showHistogram,
                        onToggleHistogram: {
                            showHistogram.toggle()
                        },
                        onExport: {}
                    )

                    PhotoLibraryHome(library: photoLibrary) { asset in
                        importLibraryAsset(asset)
                    }
                }
                .background(GrainTheme.black)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(isPresented: editorPresented) {
                    VStack(spacing: 0) {
                        MinimalTopBar(
                            hasPhoto: true,
                            onFiles: { showDocumentPicker = true },
                            onInfo: { showInfoSheet = true },
                            onSettings: { showSettings = true },
                            histogramVisible: showHistogram,
                            onToggleHistogram: {
                                showHistogram.toggle()
                            },
                            onExport: {
                                editor.exportResult = nil
                                showExportSheet = true
                            }
                        )

                        EditorWorkspace(
                            showHistogram: showHistogram,
                            onBackToLibrary: {
                                editor.returnHome()
                                Task { await photoLibrary.refresh() }
                            }
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(GrainTheme.black.ignoresSafeArea())
                    .toolbar(.hidden, for: .navigationBar)
                }
            }
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
        .sheet(isPresented: $showInfoSheet) {
            ImageInfoSheet()
                .environmentObject(editor)
                .presentationDetents([.height(520)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            AppSettingsView()
                .presentationDetents([.height(290)])
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
        .overlay(alignment: .top) {
            if let notice = editor.noticeMessage {
                Text(notice)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(GrainTheme.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(maxWidth: 360)
                    .background(GrainTheme.paper, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .padding(.top, 62)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay {
            if editor.isPreparing && editor.photo == nil {
                VStack(spacing: 10) {
                    ProgressView().tint(GrainTheme.paper)
                    Text("正在读取原始照片")
                        .font(.system(size: 9.5, weight: .medium, design: .rounded))
                        .foregroundStyle(GrainTheme.paper)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 13)
                .background(.black.opacity(0.78), in: Capsule())
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await photoLibrary.refresh()
                }
            }
        }
    }

    private var editorPresented: Binding<Bool> {
        Binding(
            get: { editor.photo != nil },
            set: { presented in
                if !presented {
                    editor.returnHome()
                    Task {
                        await photoLibrary.refresh()
                    }
                }
            }
        )
    }

    private func importLibraryAsset(_ asset: PHAsset) {
        Task {
            do {
                let url = try await photoLibrary.originalFileURL(for: asset)
                editor.importPhoto(from: url)
            } catch {
                editor.errorMessage = error.localizedDescription
            }
        }
    }
}

private struct MinimalTopBar: View {
    let hasPhoto: Bool
    let onFiles: () -> Void
    let onInfo: () -> Void
    let onSettings: () -> Void
    let histogramVisible: Bool
    let onToggleHistogram: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 9) {
                Button(action: onSettings) {
                    AnimatedCameraMark(size: 29)
                        .frame(width: 38, height: 38)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开设置")

                Text("GRAIN")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(2.3)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Spacer()

            Button(action: onFiles) {
                Image(systemName: "folder")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 38, height: 38)
                    .background(GrainTheme.raised, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("从文件导入")

            Button(action: onToggleHistogram) {
                Image(systemName: "waveform.path.ecg.rectangle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(histogramVisible ? GrainTheme.accent : GrainTheme.muted)
                    .frame(width: 38, height: 38)
                    .background(GrainTheme.raised, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(histogramVisible ? "隐藏直方图" : "显示直方图")

            Button(action: onInfo) {
                Image(systemName: "info.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(hasPhoto ? GrainTheme.paper : GrainTheme.muted)
                    .frame(width: 38, height: 38)
                    .background(GrainTheme.raised, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!hasPhoto)
            .accessibilityLabel("查看图片信息")

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

private struct EditorWorkspace: View {
    @EnvironmentObject private var editor: EditorViewModel
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    let showHistogram: Bool
    let onBackToLibrary: () -> Void
    @State private var showCropEditor = false
    @State private var editingTextID: UUID?
    @State private var selectedTextID: UUID?
    @State private var showTextEditor = false
    @State private var didSwipeBack = false

    var body: some View {
        VStack(spacing: 0) {
            PhotoEditorCanvas(
                showHistogram: showHistogram,
                selectedTextID: $selectedTextID
            ) { id in
                editingTextID = id
                selectedTextID = id
                showTextEditor = true
            }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            FilmPresetBar()
                .frame(height: 100)

            AdjustPanel(
                onCrop: { showCropEditor = true },
                onAddText: {
                    let id = editor.addTextOverlay()
                    editingTextID = id
                    selectedTextID = id
                    showTextEditor = true
                }
            )
                .frame(height: 146)
        }
        .fullScreenCover(isPresented: $showCropEditor) {
            CropEditorView()
                .environmentObject(editor)
        }
        .sheet(isPresented: $showTextEditor, onDismiss: { editingTextID = nil }) {
            if let editingTextID {
                TextOverlayEditorView(overlayID: editingTextID)
                    .environmentObject(editor)
                    .presentationDetents([.height(455)])
                    .presentationDragIndicator(.visible)
            }
        }
        .simultaneousGesture(edgeSwipeGesture)
    }

    private var edgeSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard !didSwipeBack,
                      value.startLocation.x <= 34,
                      value.translation.width > 64,
                      value.translation.width > abs(value.translation.height) * 1.35
                else { return }

                didSwipeBack = true
                GrainHaptics.mediumImpact(enabled: hapticsEnabled)
                onBackToLibrary()
            }
            .onEnded { _ in
                didSwipeBack = false
            }
    }
}

private struct PhotoEditorCanvas: View {
    @EnvironmentObject private var editor: EditorViewModel
    let showHistogram: Bool
    @Binding var selectedTextID: UUID?
    let onEditText: (UUID) -> Void
    @State private var showOriginal = false
    @State private var showFullscreen = false

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

                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTextID = nil
                            showFullscreen = true
                        }

                    ForEach(editor.textOverlays) { overlay in
                        EditableTextOverlayView(
                            overlay: overlay,
                            selected: selectedTextID == overlay.id,
                            canvasSize: CGSize(width: proxy.size.width, height: imageHeight),
                            onSelect: {
                                selectedTextID = overlay.id
                            },
                            onEdit: {
                                onEditText(overlay.id)
                            },
                            onDelete: {
                                editor.deleteTextOverlay(id: overlay.id)
                                selectedTextID = nil
                            },
                            onMoveStart: editor.recordUndoSnapshot,
                            onMove: { point in
                                editor.moveTextOverlay(
                                    id: overlay.id,
                                    x: point.x / max(proxy.size.width, 1),
                                    y: point.y / max(imageHeight, 1)
                                )
                            }
                        )
                    }

                    VStack {
                        HStack(alignment: .top, spacing: 12) {
                            Label(editor.photo?.sourceKindLabel ?? "RAW", systemImage: "circle.fill")
                                .labelStyle(.titleAndIcon)
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(GrainTheme.paper)
                                .padding(.horizontal, 9)
                                .frame(height: 24)
                                .background(.black.opacity(0.52), in: Capsule())

                            Spacer()

                            if showHistogram, let histogram = editor.histogram {
                                HistogramView(data: histogram)
                                    .frame(width: 82, height: 46)
                                    .offset(x: 5, y: -6)
                            }

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

                            Text("轻点全屏 · 按住看原片")
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
                .coordinateSpace(name: "photo-editor-canvas")
                .frame(width: proxy.size.width, height: imageHeight)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
        .fullScreenCover(isPresented: $showFullscreen) {
            FullscreenPhotoView()
                .environmentObject(editor)
        }
    }

    private var imageAspect: CGFloat {
        guard let photo = editor.photo, photo.pixelWidth > 0, photo.pixelHeight > 0 else {
            return 3 / 2
        }
        return CGFloat(photo.pixelWidth) / CGFloat(photo.pixelHeight)
    }
}

private struct EditableTextOverlayView: View {
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    let overlay: PhotoTextOverlay
    let selected: Bool
    let canvasSize: CGSize
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onMoveStart: () -> Void
    let onMove: (CGPoint) -> Void
    @State private var dragOrigin: CGPoint?
    @State private var liveCenter: CGPoint?
    @State private var lastSnapKey: String?

    var body: some View {
        Text(overlay.text.isEmpty ? " " : overlay.text)
            .font(
                overlay.font.swiftUIFont(
                    size: max(10, min(canvasSize.width, canvasSize.height) * overlay.fontSize)
                )
            )
            .foregroundStyle(
                Color(
                    red: overlay.red,
                    green: overlay.green,
                    blue: overlay.blue,
                    opacity: overlay.alpha
                )
            )
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
            .padding(9)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .stroke(GrainTheme.paper.opacity(0.9), lineWidth: 0.9)
                        .allowsHitTesting(false)
                }
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Button {
                        GrainHaptics.lightImpact(enabled: hapticsEnabled)
                        onDelete()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Color(hex: 0xB64532), in: Circle())
                            .overlay {
                                Circle().stroke(Color.white.opacity(0.75), lineWidth: 0.7)
                            }
                    }
                    .buttonStyle(.plain)
                    .offset(x: 11, y: -11)
                    .zIndex(2)
                    .accessibilityLabel("删除文字")
                }
            }
            .padding(14)
            .contentShape(Rectangle())
            .gesture(textDragGesture)
            .onTapGesture {
                if selected {
                    onEdit()
                } else {
                    onSelect()
                }
            }
        .position(
            x: displayedCenter.x,
            y: displayedCenter.y
        )
        .zIndex(selected ? 2 : 1)
    }

    private var displayedCenter: CGPoint {
        liveCenter ?? CGPoint(
            x: overlay.x * canvasSize.width,
            y: overlay.y * canvasSize.height
        )
    }

    private var textDragGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                if dragOrigin == nil {
                    dragOrigin = CGPoint(
                        x: overlay.x * canvasSize.width,
                        y: overlay.y * canvasSize.height
                    )
                    onMoveStart()
                }
                guard let origin = dragOrigin else { return }
                let rawPoint = CGPoint(
                    x: origin.x + value.translation.width,
                    y: origin.y + value.translation.height
                )
                let snapped = snappedPoint(rawPoint)
                liveCenter = snapped.point
                if snapped.key != lastSnapKey {
                    lastSnapKey = snapped.key
                    if snapped.key != nil {
                        GrainHaptics.selection(enabled: hapticsEnabled)
                    }
                }
            }
            .onEnded { _ in
                if let liveCenter {
                    onMove(liveCenter)
                }
                dragOrigin = nil
                liveCenter = nil
                lastSnapKey = nil
            }
    }

    private func snappedPoint(_ point: CGPoint) -> (point: CGPoint, key: String?) {
        let snapDistance: CGFloat = 20
        let anchors: [CGFloat] = [0.15, 0.50, 0.85]
        var snappedX = point.x
        var snappedY = point.y
        var xKey: Int?
        var yKey: Int?

        for (index, anchor) in anchors.enumerated() {
            let targetX = anchor * canvasSize.width
            if abs(point.x - targetX) <= snapDistance {
                snappedX = targetX
                xKey = index
                break
            }
        }
        for (index, anchor) in anchors.enumerated() {
            let targetY = anchor * canvasSize.height
            if abs(point.y - targetY) <= snapDistance {
                snappedY = targetY
                yKey = index
                break
            }
        }

        let key: String?
        if xKey != nil || yKey != nil {
            key = "\(xKey ?? -1)-\(yKey ?? -1)"
        } else {
            key = nil
        }
        return (CGPoint(x: snappedX, y: snappedY), key)
    }
}

private struct HistogramView: View {
    let data: RGBHistogram

    var body: some View {
        Canvas { context, size in
            let inset: CGFloat = 4
            let width = max(size.width - inset * 2, 1)
            let height = max(size.height - inset * 2, 1)

            var fill = Path()
            fill.move(to: CGPoint(x: inset, y: inset + height))
            for (index, value) in data.luminance.enumerated() {
                let x = inset + CGFloat(index) / CGFloat(max(data.luminance.count - 1, 1)) * width
                let y = inset + height - CGFloat(value) * height
                fill.addLine(to: CGPoint(x: x, y: y))
            }
            fill.addLine(to: CGPoint(x: inset + width, y: inset + height))
            fill.closeSubpath()
            context.fill(fill, with: .color(Color.white.opacity(0.20)))

            draw(channel: data.red, color: Color.red.opacity(0.72), in: context, size: size, inset: inset)
            draw(channel: data.green, color: Color.green.opacity(0.62), in: context, size: size, inset: inset)
            draw(channel: data.blue, color: Color.cyan.opacity(0.72), in: context, size: size, inset: inset)
        }
        .padding(4)
        .background(Color.black.opacity(0.52), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.7)
        }
        .accessibilityLabel("图像直方图")
    }

    private func draw(
        channel: [Double],
        color: Color,
        in context: GraphicsContext,
        size: CGSize,
        inset: CGFloat
    ) {
        let width = max(size.width - inset * 2, 1)
        let height = max(size.height - inset * 2, 1)
        var path = Path()
        for (index, value) in channel.enumerated() {
            let x = inset + CGFloat(index) / CGFloat(max(channel.count - 1, 1)) * width
            let y = inset + height - CGFloat(value) * height
            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.stroke(path, with: .color(color), lineWidth: 0.8)
    }
}

private struct FullscreenPhotoView: View {
    @EnvironmentObject private var editor: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset = CGSize.zero
    @State private var lastOffset = CGSize.zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image = editor.editedPreview {
                GeometryReader { proxy in
                    let rect = fittedRect(for: image, in: proxy.size)
                    ZStack {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .frame(width: rect.width, height: rect.height)

                        ForEach(editor.textOverlays) { overlay in
                            Text(overlay.text)
                                .font(
                                    overlay.font.swiftUIFont(
                                        size: max(10, min(rect.width, rect.height) * overlay.fontSize)
                                    )
                                )
                                .foregroundStyle(
                                    Color(
                                        red: overlay.red,
                                        green: overlay.green,
                                        blue: overlay.blue,
                                        opacity: overlay.alpha
                                    )
                                )
                                .multilineTextAlignment(.center)
                                .position(
                                    x: overlay.x * rect.width,
                                    y: overlay.y * rect.height
                                )
                        }
                    }
                    .frame(width: rect.width, height: rect.height)
                    .scaleEffect(scale)
                    .offset(offset)
                    .position(x: rect.midX, y: rect.midY)
                    .gesture(magnificationGesture)
                    .simultaneousGesture(dragGesture)
                    .onTapGesture(count: 2, perform: toggleZoom)
                    .animation(.easeOut(duration: 0.16), value: scale)
                    .animation(.easeOut(duration: 0.16), value: offset)
                }
            } else {
                ProgressView()
                    .tint(GrainTheme.paper)
            }

            VStack(spacing: 0) {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 86)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismiss()
                    }

                Spacer()

                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 82)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        dismiss()
                    }
            }

            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(GrainTheme.paper)
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.58), in: Circle())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(editor.selectedProfile.name)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(GrainTheme.paper)
                        .padding(.horizontal, 11)
                        .frame(height: 29)
                        .background(Color.black.opacity(0.58), in: Capsule())
                }
                .padding(.horizontal, 16)

                Spacer()

                Text("点上方或下方空白返回 · 双指缩放")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(GrainTheme.paper.opacity(0.72))
                    .padding(.horizontal, 12)
                    .frame(height: 28)
                    .background(Color.black.opacity(0.56), in: Capsule())
                    .onTapGesture {
                        dismiss()
                    }
                    .padding(.bottom, 28)
            }
        }
        .statusBarHidden()
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 6)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1.01 {
                    resetTransform()
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard scale > 1.01 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private func toggleZoom() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if scale > 1.05 {
                resetTransform()
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }

    private func resetTransform() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.82)) {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        }
    }

    private func fittedRect(for image: CGImage, in size: CGSize) -> CGRect {
        let imageRatio = CGFloat(image.width) / CGFloat(image.height)
        let sizeRatio = size.width / max(size.height, 1)
        let fitted: CGSize
        if imageRatio > sizeRatio {
            fitted = CGSize(width: size.width, height: size.width / imageRatio)
        } else {
            fitted = CGSize(width: size.height * imageRatio, height: size.height)
        }
        return CGRect(
            x: (size.width - fitted.width) / 2,
            y: (size.height - fitted.height) / 2,
            width: fitted.width,
            height: fitted.height
        )
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Spacer()

                Button {
                    editor.undo()
                } label: {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(editor.canUndo ? GrainTheme.paper : GrainTheme.muted.opacity(0.38))
                        .frame(width: 27, height: 24)
                        .background(GrainTheme.raised, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!editor.canUndo)
                .accessibilityLabel("撤销上一步")

                Button {
                    editor.copyPreset()
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(GrainTheme.muted)
                        .padding(.horizontal, 7)
                        .frame(height: 24)
                        .background(GrainTheme.raised, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("复制调色预设")

                Button {
                    editor.pastePreset()
                } label: {
                    Label("粘贴", systemImage: "doc.on.clipboard")
                        .font(.system(size: 8.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(GrainTheme.muted)
                        .padding(.horizontal, 7)
                        .frame(height: 24)
                        .background(GrainTheme.raised, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("粘贴调色预设")

                Button {
                    editor.recommendLook()
                } label: {
                    HStack(spacing: 4) {
                        if editor.isRecommending {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(GrainTheme.accent)
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                        Text("推荐")
                    }
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(editor.isRecommendationApplied ? GrainTheme.accent : GrainTheme.muted)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(
                        editor.isRecommendationApplied
                            ? GrainTheme.accent.opacity(0.12)
                            : GrainTheme.raised,
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                .disabled(editor.isRecommending)

                Button {
                    editor.resetAllAdjustments()
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
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    let onCrop: () -> Void
    let onAddText: () -> Void
    @State private var selectedCategory: AdjustCategory = .light
    @State private var selectedTool: AdjustTool = .exposure
    @State private var lastHapticValue = Double.nan

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 22) {
                ForEach(AdjustCategory.allCases) { category in
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            selectedCategory = category
                            selectedTool = tools(for: category).first ?? .exposure
                            lastHapticValue = value(for: selectedTool)
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

                Button(action: onCrop) {
                    Image(systemName: "crop.rotate")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GrainTheme.paper)
                        .frame(width: 30, height: 27)
                        .background(GrainTheme.raised, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("裁剪与构图")

                Button(action: onAddText) {
                    Image(systemName: "textformat")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(GrainTheme.paper)
                        .frame(width: 30, height: 27)
                        .background(GrainTheme.raised, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("添加文字")
            }
            .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(tools(for: selectedCategory)) { tool in
                        Button {
                            selectedTool = tool
                            lastHapticValue = value(for: tool)
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
                Slider(
                    value: activeBinding,
                    in: activeRange,
                    onEditingChanged: { editing in
                        if editing {
                            editor.recordUndoSnapshot()
                            lastHapticValue = value(for: selectedTool)
                            GrainHaptics.prepare()
                        }
                    }
                )
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
                editor.markManualAdjustment()
                emitSliderHaptic(for: $0)
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

    private func emitSliderHaptic(for value: Double) {
        let step: Double
        switch selectedTool {
        case .exposure: step = 0.05
        case .temperature: step = 50
        case .intensity, .fade, .grain, .vignette, .sharpness: step = 2
        default: step = 5
        }
        guard !lastHapticValue.isNaN, abs(value - lastHapticValue) >= step else { return }
        lastHapticValue = value
        GrainHaptics.selection(enabled: hapticsEnabled)
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
