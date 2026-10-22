import Foundation

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])

let metadata = try RawImageProcessor.metadata(for: input)
let preview = try RawImageProcessor.renderPreview(
    from: input,
    profile: .portra,
    settings: FilmProfile.portra.factorySettings,
    intensity: 0.82
)

let result = try RawImageProcessor.export(
    from: input,
    profile: .portra,
    settings: FilmProfile.portra.factorySettings,
    intensity: 0.82,
    options: ExportOptions(format: .jpeg, quality: 1.0, keepLocation: false),
    to: output
)

print("metadata=\(metadata.pixelWidth)x\(metadata.pixelHeight)")
print("preview=\(preview.edited.width)x\(preview.edited.height)")
print("export=\(result.dimensions) format=\(result.format.title) path=\(result.url.path)")
