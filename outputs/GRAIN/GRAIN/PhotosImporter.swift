import Foundation
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
            forOpeningContentTypes: [.rawImage, .image],
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

            let rawExtensions = Set(["arw", "srf", "sr2", "dng"])
            let typeIdentifier = provider.registeredTypeIdentifiers.first { identifier in
                guard let type = UTType(identifier),
                      let fileExtension = type.preferredFilenameExtension
                else { return false }
                return rawExtensions.contains(fileExtension.lowercased())
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
