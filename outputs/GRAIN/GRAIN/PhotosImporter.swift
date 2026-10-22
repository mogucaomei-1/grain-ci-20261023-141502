import Foundation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct DocumentRawImporter: UIViewControllerRepresentable {
    let onImport: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.data, .image],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: DocumentRawImporter

        init(parent: DocumentRawImporter) {
            self.parent = parent
        }

        func documentPicker(
            _ controller: UIDocumentPickerViewController,
            didPickDocumentsAt urls: [URL]
        ) {
            guard let url = urls.first else {
                parent.onCancel()
                return
            }
            parent.onImport(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.onCancel()
        }
    }
}

struct PhotosRawImporter: UIViewControllerRepresentable {
    let onImport: (URL) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: PhotosRawImporter

        init(parent: PhotosRawImporter) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider else {
                parent.onCancel()
                return
            }

            if let assetIdentifier = results.first?.assetIdentifier {
                loadOriginalAsset(assetIdentifier: assetIdentifier) {
                    loadItemProvider(provider)
                }
                return
            }

            loadItemProvider(provider)
        }

        private func loadOriginalAsset(assetIdentifier: String, fallback: @escaping () -> Void) {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            guard let asset = assets.firstObject else {
                fallback()
                return
            }

            let rawMarkers = ["arw", "srf", "sr2", "dng", "camera-raw"]
            let resources = PHAssetResource.assetResources(for: asset)
            let rawResource = resources.first { resource in
                let identifier = resource.uniformTypeIdentifier.lowercased()
                let filename = resource.originalFilename.lowercased()
                return rawMarkers.contains { identifier.contains($0) || filename.hasSuffix(".\($0)") }
            }

            guard let rawResource else {
                fallback()
                return
            }

            let destination = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(
                    (rawResource.originalFilename as NSString).pathExtension.isEmpty
                        ? "arw"
                        : (rawResource.originalFilename as NSString).pathExtension
                )
            let options = PHAssetResourceRequestOptions()
            options.isNetworkAccessAllowed = true

            PHAssetResourceManager.default().writeData(
                for: rawResource,
                toFile: destination,
                options: options
            ) { [parent] error in
                guard error == nil else {
                    fallback()
                    return
                }
                DispatchQueue.main.async {
                    parent.onImport(destination)
                }
            }
        }

        private func loadItemProvider(_ provider: NSItemProvider) {
            let rawMarkers = ["arw", "srf", "sr2", "dng", "camera-raw"]
            let typeIdentifier = provider.registeredTypeIdentifiers.first { identifier in
                let lowercased = identifier.lowercased()
                return rawMarkers.contains { lowercased.contains($0) }
            } ?? provider.registeredTypeIdentifiers.first { identifier in
                guard let type = UTType(identifier) else { return false }
                return type.conforms(to: .rawImage)
            } ?? provider.registeredTypeIdentifiers.first { identifier in
                guard let type = UTType(identifier) else { return false }
                return type.conforms(to: .image)
            }

            guard let typeIdentifier else {
                parent.onCancel()
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [parent] url, _ in
                guard let url else {
                    DispatchQueue.main.async { parent.onCancel() }
                    return
                }

                let extensionName = UTType(typeIdentifier)?.preferredFilenameExtension
                    ?? (url.pathExtension.isEmpty ? "raw" : url.pathExtension)
                let destination = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(extensionName)

                do {
                    try FileManager.default.copyItem(at: url, to: destination)
                    DispatchQueue.main.async {
                        parent.onImport(destination)
                    }
                } catch {
                    DispatchQueue.main.async {
                        parent.onCancel()
                    }
                }
            }
        }
    }
}

enum PhotoLibraryAccess {
    static func request() async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    continuation.resume(returning: status == .authorized || status == .limited)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
