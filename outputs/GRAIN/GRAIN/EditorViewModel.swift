import CoreGraphics
import Foundation
import SwiftUI

@MainActor
final class EditorViewModel: ObservableObject {
    @Published private(set) var photo: PhotoAsset?
    @Published private(set) var originalPreview: CGImage?
    @Published private(set) var editedPreview: CGImage?
    @Published private(set) var isPreparing = false
    @Published private(set) var isExporting = false
    @Published var selectedProfile: FilmProfile = .portra
    @Published var settings: FilmSettings = FilmProfile.portra.factorySettings
    @Published var intensity = 0.82
    @Published var exportOptions = ExportOptions()
    @Published var errorMessage: String?
    @Published var exportResult: ExportResult?

    private var previewTask: Task<Void, Never>?

    var canExport: Bool {
        photo != nil && !isPreparing && !isExporting
    }

    func selectProfile(_ profile: FilmProfile) {
        withAnimation(.snappy(duration: 0.25)) {
            selectedProfile = profile
            settings = profile.factorySettings
            intensity = profile == .neutral ? 1 : 0.82
        }
        schedulePreview()
    }

    func returnHome() {
        previewTask?.cancel()
        previewTask = nil
        photo = nil
        originalPreview = nil
        editedPreview = nil
        exportResult = nil
        errorMessage = nil
        isPreparing = false
        isExporting = false
    }

    func resetSelectedProfile() {
        withAnimation(.snappy(duration: 0.25)) {
            settings = selectedProfile.factorySettings
            intensity = selectedProfile == .neutral ? 1 : 0.82
        }
        schedulePreview()
    }

    func schedulePreview() {
        guard let photo else { return }
        previewTask?.cancel()
        let profile = selectedProfile
        let settings = settings
        let intensity = intensity

        previewTask = Task {
            try? await Task.sleep(for: .milliseconds(110))
            guard !Task.isCancelled else { return }
            isPreparing = true
            do {
                let rendered = try await Task.detached(priority: .userInitiated) {
                    try RawImageProcessor.renderPreview(
                        from: photo.url,
                        profile: profile,
                        settings: settings,
                        intensity: intensity
                    )
                }.value
                guard !Task.isCancelled else { return }
                originalPreview = rendered.original
                editedPreview = rendered.edited
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
            isPreparing = false
        }
    }

    func importPhoto(from incomingURL: URL) {
        errorMessage = nil
        isPreparing = true
        exportResult = nil

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
            photo = asset
            exportOptions.keepLocation = asset.hasLocation
            schedulePreview()
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
}
