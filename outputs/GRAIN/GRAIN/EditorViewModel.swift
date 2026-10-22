import CoreGraphics
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class EditorViewModel: ObservableObject {
    @Published private(set) var photo: PhotoAsset?
    @Published private(set) var originalPreview: CGImage?
    @Published private(set) var fullGradedPreview: CGImage?
    @Published private(set) var editedPreview: CGImage?
    @Published private(set) var histogram: RGBHistogram?
    @Published private(set) var isPreparing = false
    @Published private(set) var isRecommending = false
    @Published private(set) var isRecommendationApplied = false
    @Published private(set) var canUndo = false
    @Published private(set) var isExporting = false
    @Published var selectedProfile: FilmProfile = .portra
    @Published var settings: FilmSettings = FilmProfile.portra.factorySettings
    @Published var intensity = 0.82
    @Published var exportOptions = ExportOptions()
    @Published var crop = CropTransform.identity
    @Published var textOverlays: [PhotoTextOverlay] = []
    @Published var errorMessage: String?
    @Published var exportResult: ExportResult?
    @Published var noticeMessage: String?

    private var previewTask: Task<Void, Never>?
    private var importTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var sourcePreview: CGImage?
    private var previewNeedsUpdate = false
    private var previewGeneration = 0
    private var undoStack: [EditorSnapshot] = []

    var canExport: Bool {
        photo != nil && !isPreparing && !isExporting
    }

    func selectProfile(_ profile: FilmProfile) {
        recordUndoSnapshot()
        withAnimation(.snappy(duration: 0.25)) {
            selectedProfile = profile
            settings = profile.factorySettings
            intensity = profile == .neutral ? 1 : 0.82
            isRecommendationApplied = false
        }
        schedulePreview()
    }

    func returnHome() {
        previewTask?.cancel()
        importTask?.cancel()
        previewTask = nil
        previewNeedsUpdate = false
        previewGeneration += 1
        photo = nil
        sourcePreview = nil
        originalPreview = nil
        fullGradedPreview = nil
        editedPreview = nil
        histogram = nil
        crop = .identity
        textOverlays = []
        exportResult = nil
        errorMessage = nil
        isPreparing = false
        isExporting = false
        isRecommendationApplied = false
        undoStack.removeAll()
        canUndo = false
    }

    func resetSelectedProfile() {
        recordUndoSnapshot()
        withAnimation(.snappy(duration: 0.25)) {
            settings = selectedProfile.factorySettings
            intensity = selectedProfile == .neutral ? 1 : 0.82
            isRecommendationApplied = false
        }
        schedulePreview()
    }

    func resetAllAdjustments() {
        recordUndoSnapshot()
        withAnimation(.snappy(duration: 0.25)) {
            selectedProfile = .neutral
            settings = FilmProfile.neutral.factorySettings
            intensity = 1
            isRecommendationApplied = false
        }
        schedulePreview()
    }

    func recommendLook() {
        guard let originalPreview, !isRecommending else { return }
        recordUndoSnapshot()
        isRecommending = true

        Task {
            let recommendation = await Task.detached(priority: .userInitiated) {
                LocalLookAdvisor.recommend(from: originalPreview)
            }.value

            withAnimation(.snappy(duration: 0.24)) {
                selectedProfile = recommendation.profile
                settings = recommendation.settings
                intensity = recommendation.intensity
                isRecommendationApplied = true
            }
            schedulePreview()
            isRecommending = false
        }
    }

    func copyPreset() {
        guard photo != nil else { return }
#if canImport(UIKit)
        do {
            let preset = PresetClipboard(
                profile: selectedProfile,
                settings: settings,
                intensity: intensity
            )
            let data = try JSONEncoder().encode(preset)
            UIPasteboard.general.string = "GRAIN-PRESET-V1:\(data.base64EncodedString())"
            showNotice("已复制当前调色预设")
        } catch {
            errorMessage = "复制预设失败：\(error.localizedDescription)"
        }
#endif
    }

    func pastePreset() {
#if canImport(UIKit)
        guard let text = UIPasteboard.general.string,
              text.hasPrefix("GRAIN-PRESET-V1:"),
              let data = Data(base64Encoded: String(text.dropFirst("GRAIN-PRESET-V1:".count))),
              let preset = try? JSONDecoder().decode(PresetClipboard.self, from: data),
              preset.version == 1
        else {
            errorMessage = "剪贴板中没有可用的 GRAIN 调色预设。"
            return
        }

        recordUndoSnapshot()
        withAnimation(.snappy(duration: 0.24)) {
            selectedProfile = preset.profile
            settings = preset.settings
            intensity = preset.intensity
            isRecommendationApplied = false
        }
        schedulePreview()
        showNotice("已粘贴预设 · \(preset.profile.name)")
#endif
    }

    func updateCrop(_ newCrop: CropTransform) {
        recordUndoSnapshot()
        crop = newCrop
        isRecommendationApplied = false
        schedulePreview()
    }

    @discardableResult
    func addTextOverlay() -> UUID {
        recordUndoSnapshot()
        var overlay = PhotoTextOverlay()
        overlay.y = 0.68
        textOverlays.append(overlay)
        return overlay.id
    }

    func updateTextOverlay(_ overlay: PhotoTextOverlay) {
        guard let index = textOverlays.firstIndex(where: { $0.id == overlay.id }) else { return }
        recordUndoSnapshot()
        textOverlays[index] = overlay
    }

    func moveTextOverlay(id: UUID, x: Double, y: Double) {
        guard let index = textOverlays.firstIndex(where: { $0.id == id }) else { return }
        textOverlays[index].x = min(max(x, 0.04), 0.96)
        textOverlays[index].y = min(max(y, 0.04), 0.96)
    }

    func deleteTextOverlay(id: UUID) {
        recordUndoSnapshot()
        textOverlays.removeAll { $0.id == id }
    }

    func markManualAdjustment() {
        isRecommendationApplied = false
    }

    func recordUndoSnapshot() {
        let snapshot = currentSnapshot
        guard undoStack.last != snapshot else { return }
        undoStack.append(snapshot)
        if undoStack.count > 40 {
            undoStack.removeFirst()
        }
        canUndo = true
    }

    func undo() {
        guard let snapshot = undoStack.popLast() else { return }
        withAnimation(.snappy(duration: 0.24)) {
            selectedProfile = snapshot.profile
            settings = snapshot.settings
            intensity = snapshot.intensity
            crop = snapshot.crop
            textOverlays = snapshot.overlays
            isRecommendationApplied = snapshot.recommendationApplied
        }
        canUndo = !undoStack.isEmpty
        schedulePreview()
    }

    func schedulePreview() {
        guard sourcePreview != nil else { return }
        previewNeedsUpdate = true
        guard previewTask == nil else { return }

        let generation = previewGeneration
        previewTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled, self.previewGeneration == generation {
                guard self.previewNeedsUpdate, let sourcePreview = self.sourcePreview else { break }
                self.previewNeedsUpdate = false
                let profile = self.selectedProfile
                let settings = self.settings
                let intensity = self.intensity
                let suppressVignette = self.photo?.isLikelyScreenshot ?? false
                let crop = self.crop

                do {
                    let rendered = try await Task.detached(priority: .userInitiated) {
                        let edited = try RawImageProcessor.renderGradedPreview(
                            source: sourcePreview,
                            profile: profile,
                            settings: settings,
                            intensity: intensity,
                            suppressVignette: suppressVignette
                        )
                        let cropped = CropProcessor.apply(crop, to: edited)
                        return (
                            full: edited,
                            edited: cropped,
                            histogram: LocalLookAdvisor.histogram(from: cropped)
                        )
                    }.value
                    guard !Task.isCancelled, self.previewGeneration == generation else { break }
                    self.fullGradedPreview = rendered.full
                    self.editedPreview = rendered.edited
                    self.histogram = rendered.histogram
                } catch {
                    if !Task.isCancelled {
                        self.errorMessage = error.localizedDescription
                    }
                    break
                }
            }

            if self.previewGeneration == generation {
                self.previewTask = nil
                if self.previewNeedsUpdate {
                    self.schedulePreview()
                }
            }
        }
    }

    func importPhoto(from incomingURL: URL) {
        errorMessage = nil
        isPreparing = true
        exportResult = nil
        previewTask?.cancel()
        previewTask = nil
        previewNeedsUpdate = false
        previewGeneration += 1

        let supportedExtensions = ["arw", "srf", "sr2", "dng", "jpg", "jpeg", "heic", "heif", "png"]
        guard supportedExtensions.contains(incomingURL.pathExtension.lowercased()) else {
            isPreparing = false
            errorMessage = "请选择 Sony ARW、DNG、HEIC 或 JPEG 图片。"
            return
        }

        let accessed = incomingURL.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                incomingURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let localURL = try copyIntoLibrary(incomingURL)
            let asset = try RawImageProcessor.metadata(for: localURL)
            let quickPreview = try RawImageProcessor.renderQuickPreview(from: localURL)

            sourcePreview = quickPreview
            originalPreview = quickPreview
            fullGradedPreview = nil
            editedPreview = nil
            histogram = nil
            crop = .identity
            textOverlays = []
            selectedProfile = .neutral
            settings = FilmProfile.neutral.factorySettings
            intensity = 1
            photo = asset
            exportOptions.keepLocation = asset.hasLocation
            undoStack.removeAll()
            canUndo = false
            isRecommendationApplied = false
            isPreparing = false
            schedulePreview()

            importTask?.cancel()
            let generation = previewGeneration
            importTask = Task {
                do {
                    let source = try await Task.detached(priority: .userInitiated) {
                        try RawImageProcessor.renderSourcePreview(from: localURL)
                    }.value
                    guard !Task.isCancelled, previewGeneration == generation else { return }

                    sourcePreview = source
                    originalPreview = source
                    schedulePreview()
                } catch {
                    guard !Task.isCancelled else { return }
                    if incomingURL.pathExtension.lowercased().contains("arw") {
                        noticeMessage = "已显示快速预览，但当前 iOS 无法解码该 RAW 的全尺寸图像。"
                    }
                }
            }
        } catch {
            isPreparing = false
            errorMessage = error.localizedDescription
        }
    }

    func export() {
        guard let photo, !isExporting else { return }
        isExporting = true
        errorMessage = nil

        let profile = selectedProfile
        let settings = settings
        let intensity = intensity
        let options = exportOptions
        let crop = crop
        let textOverlays = textOverlays
        let format = options.format
        let stem = makeExportStem(for: photo, profile: profile)
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(stem)
            .appendingPathExtension(format.fileExtension)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try RawImageProcessor.export(
                        from: photo.url,
                        profile: profile,
                        settings: settings,
                        intensity: intensity,
                        options: options,
                        crop: crop,
                        textOverlays: textOverlays,
                        to: outputURL
                    )
                }.value
                exportResult = result
            } catch {
                errorMessage = error.localizedDescription
            }
            isExporting = false
        }
    }

    private func copyIntoLibrary(_ sourceURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let root = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let imports = root.appendingPathComponent("GRAIN/Imports", isDirectory: true)
        try fileManager.createDirectory(at: imports, withIntermediateDirectories: true)

        let originalExtension = sourceURL.pathExtension.isEmpty ? "raw" : sourceURL.pathExtension
        let destination = imports
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(originalExtension)

        do {
            try fileManager.copyItem(at: sourceURL, to: destination)
        } catch {
            // The shared photo picker may already return a file-backed provider URL.
            // If a copy races with provider cleanup, retry once after reading the bytes.
            let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
            try data.write(to: destination, options: .atomic)
        }
        return destination
    }

    private func makeExportStem(for photo: PhotoAsset, profile: FilmProfile) -> String {
        let cleanName = photo.displayName
            .replacingOccurrences(of: #"[^A-Za-z0-9_-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let prefix = cleanName.isEmpty ? "GRAIN" : cleanName
        let look = profile.shortName.lowercased()
        return "\(prefix)-\(look)-fullres"
    }

    private func showNotice(_ text: String, duration: Double = 2.8) {
        noticeTask?.cancel()
        withAnimation(.easeOut(duration: 0.16)) {
            noticeMessage = text
        }
        noticeTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.18)) {
                noticeMessage = nil
            }
        }
    }

    private var currentSnapshot: EditorSnapshot {
        EditorSnapshot(
            profile: selectedProfile,
            settings: settings,
            intensity: intensity,
            crop: crop,
            overlays: textOverlays,
            recommendationApplied: isRecommendationApplied
        )
    }
}

private struct EditorSnapshot: Equatable {
    let profile: FilmProfile
    let settings: FilmSettings
    let intensity: Double
    let crop: CropTransform
    let overlays: [PhotoTextOverlay]
    let recommendationApplied: Bool
}
