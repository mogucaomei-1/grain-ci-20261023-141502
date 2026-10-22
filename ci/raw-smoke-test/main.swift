import Foundation

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

let asset = try RawImageProcessor.metadata(for: sourceURL)
let preview = try RawImageProcessor.renderPreview(
    from: sourceURL,
    profile: .portra,
    settings: FilmProfile.portra.factorySettings,
    intensity: 0.82
)
let result = try RawImageProcessor.export(
    from: sourceURL,
    profile: .portra,
    settings: FilmProfile.portra.factorySettings,
    intensity: 0.82,
    options: ExportOptions(format: .jpeg, quality: 0.95, keepLocation: false),
    to: outputURL
)

guard result.format == .jpeg else {
    fatalError("RAW export did not produce a JPEG")
}
guard FileManager.default.fileExists(atPath: outputURL.path) else {
    fatalError("RAW export produced no file")
}
guard preview.edited.width > 0, preview.original.height > 0 else {
    fatalError("RAW preview is empty")
}

print("RAW camera: \(asset.cameraLabel)")
print("RAW source: \(asset.pixelWidth)x\(asset.pixelHeight)")
print("Preview: \(preview.edited.width)x\(preview.edited.height)")
print("Export: \(result.dimensions)")
print("RAW_SMOKE_TEST_OK")

