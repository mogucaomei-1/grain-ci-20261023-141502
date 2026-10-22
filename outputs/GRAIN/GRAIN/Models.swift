import Foundation
import ImageIO
import UniformTypeIdentifiers

enum FilmProfile: String, CaseIterable, Identifiable, Codable, Sendable {
    case neutral
    case portra
    case pro400h
    case gold
    case classicChrome
    case cinestill
    case hp5

    var id: String { rawValue }

    var name: String {
        switch self {
        case .neutral: "RAW Neutral"
        case .portra: "Portra 400"
        case .pro400h: "Pro 400H"
        case .gold: "Gold 200"
        case .classicChrome: "Classic Chrome"
        case .cinestill: "CineStill 800T"
        case .hp5: "HP5 Plus"
        }
    }

    var shortName: String {
        switch self {
        case .neutral: "NEUTRAL"
        case .portra: "PORTRA"
        case .pro400h: "400H"
        case .gold: "GOLD"
        case .classicChrome: "CHROME"
        case .cinestill: "800T"
        case .hp5: "HP5"
        }
    }

    var descriptor: String {
        switch self {
        case .neutral: "忠实还原传感器色彩"
        case .portra: "奶油高光 · 柔和肤色"
        case .pro400h: "薄荷青绿 · 空气感"
        case .gold: "金色午后 · 饱满暖调"
        case .classicChrome: "低饱和 · 深青阴影"
        case .cinestill: "钨丝蓝 · 夜景红晕"
        case .hp5: "银盐灰阶 · 粗粝颗粒"
        }
    }

    var palette: [UInt32] {
        switch self {
        case .neutral: [0x8B8D8A, 0xB7B3A9, 0xDFD8CB]
        case .portra: [0xB86F58, 0xD6AA86, 0xEADCC7]
        case .pro400h: [0x5F7F79, 0xAABDB0, 0xDDDAC7]
        case .gold: [0xA84A31, 0xD79D54, 0xE9D3A2]
        case .classicChrome: [0x344A49, 0x7F8B82, 0xB9B5A7]
        case .cinestill: [0x2D5568, 0xB44E42, 0xD8B4A1]
        case .hp5: [0x2A2A28, 0x84817A, 0xD6D0C4]
        }
    }

    var factorySettings: FilmSettings {
        switch self {
        case .neutral:
            .init(exposure: 0, temperature: 6500, tint: 0,
                  highlights: 0, shadows: 0, whites: 0, blacks: 0,
                  contrast: 0, vibrance: 0, saturation: 0, clarity: 0,
                  fade: 0, grain: 2, vignette: 4, sharpness: 8)
        case .portra:
            .init(exposure: 0.12, temperature: 6900, tint: 5,
                  highlights: -8, shadows: 8, whites: -3, blacks: 5,
                  contrast: -8, vibrance: 5, saturation: -10, clarity: -4,
                  fade: 10, grain: 18, vignette: 10, sharpness: 5)
        case .pro400h:
            .init(exposure: 0.22, temperature: 7100, tint: -8,
                  highlights: -10, shadows: 12, whites: -4, blacks: 8,
                  contrast: -12, vibrance: 4, saturation: -16, clarity: -7,
                  fade: 14, grain: 14, vignette: 6, sharpness: 4)
        case .gold:
            .init(exposure: 0.02, temperature: 7600, tint: 8,
                  highlights: -4, shadows: 6, whites: 4, blacks: 3,
                  contrast: 6, vibrance: 10, saturation: 10, clarity: 2,
                  fade: 8, grain: 22, vignette: 16, sharpness: 7)
        case .classicChrome:
            .init(exposure: -0.04, temperature: 6200, tint: 1,
                  highlights: -8, shadows: 4, whites: 4, blacks: 6,
                  contrast: 12, vibrance: -8, saturation: -28, clarity: 4,
                  fade: 5, grain: 14, vignette: 18, sharpness: 9)
        case .cinestill:
            .init(exposure: 0.10, temperature: 4750, tint: -8,
                  highlights: -5, shadows: 10, whites: -2, blacks: 4,
                  contrast: -4, vibrance: 8, saturation: 4, clarity: -2,
                  fade: 12, grain: 26, vignette: 22, sharpness: 2)
        case .hp5:
            .init(exposure: 0.04, temperature: 6500, tint: 0,
                  highlights: -4, shadows: 8, whites: 0, blacks: 6,
                  contrast: 14, vibrance: 0, saturation: 0, clarity: 6,
                  fade: 8, grain: 36, vignette: 16, sharpness: 10)
        }
    }
}

struct FilmSettings: Equatable, Sendable {
    var exposure: Double
    var temperature: Double
    var tint: Double
    var highlights: Double
    var shadows: Double
    var whites: Double
    var blacks: Double
    var contrast: Double
    var vibrance: Double
    var saturation: Double
    var clarity: Double
    var fade: Double
    var grain: Double
    var vignette: Double
    var sharpness: Double
}

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case heic
    case jpeg

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heic: "HEIC"
        case .jpeg: "JPEG"
        }
    }

    var subtitle: String {
        switch self {
        case .heic: "高画质 · 更小体积"
        case .jpeg: "兼容性最佳"
        }
    }

    var typeIdentifier: CFString {
        switch self {
        case .heic: UTType.heic.identifier as CFString
        case .jpeg: UTType.jpeg.identifier as CFString
        }
    }

    var fileExtension: String {
        switch self {
        case .heic: "heic"
        case .jpeg: "jpg"
        }
    }
}

struct ExportOptions: Equatable, Sendable {
    var format: ExportFormat = .heic
    var quality: Double = 1.0
    var keepLocation = true
    var keepCameraMetadata = true
}

struct PhotoAsset: Identifiable, Equatable, Sendable {
    let id = UUID()
    let url: URL
    let displayName: String
    let pixelWidth: Int
    let pixelHeight: Int
    let fileSize: Int64
    let cameraMake: String
    let cameraModel: String
    let lensModel: String
    let capturedAt: Date?
    let hasLocation: Bool
    let orientation: UInt32

    var dimensionsLabel: String {
        "\(pixelWidth) × \(pixelHeight)"
    }

    var megapixelsLabel: String {
        let megapixels = Double(pixelWidth * pixelHeight) / 1_000_000
        return String(format: "%.1f MP", megapixels)
    }

    var fileSizeLabel: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var cameraLabel: String {
        [cameraMake, cameraModel]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: "Sony Sony", with: "Sony")
    }
}

struct ExportResult: Identifiable, Sendable {
    let id = UUID()
    let url: URL
    let dimensions: String
    let format: ExportFormat
}
