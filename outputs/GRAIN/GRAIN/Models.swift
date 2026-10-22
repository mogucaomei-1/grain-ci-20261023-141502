import Foundation
import ImageIO
import UniformTypeIdentifiers

enum FilmProfile: String, CaseIterable, Identifiable, Codable, Sendable {
    case neutral
    case portra
    case film135t
    case portra160
    case portra800
    case pro400h
    case gold
    case ektar100
    case classicChrome
    case velvia50
    case provia100f
    case superia400
    case cinestill
    case vision250d
    case hp5
    case triX
    case delta3200

    var id: String { rawValue }

    var name: String {
        switch self {
        case .neutral: "原图"
        case .portra: "柯达 波特拉 400"
        case .film135t: "135T 街拍"
        case .portra160: "柯达 波特拉 160"
        case .portra800: "柯达 波特拉 800"
        case .pro400h: "富士 专业 400H"
        case .gold: "柯达 金 200"
        case .ektar100: "柯达 艾克塔 100"
        case .classicChrome: "富士 经典正片"
        case .velvia50: "富士 维尔维亚 50"
        case .provia100f: "富士 普罗维亚 100F"
        case .superia400: "富士 超级 400"
        case .cinestill: "电影 夜光 800T"
        case .vision250d: "电影 Vision3 250D"
        case .hp5: "伊尔福 HP5 Plus"
        case .triX: "柯达 Tri-X 400"
        case .delta3200: "伊尔福 Delta 3200"
        }
    }

    var shortName: String {
        switch self {
        case .neutral: "原图"
        case .portra: "波特拉"
        case .film135t: "135T"
        case .portra160: "P160"
        case .portra800: "P800"
        case .pro400h: "400H"
        case .gold: "金200"
        case .ektar100: "艾克塔"
        case .classicChrome: "经典"
        case .velvia50: "维尔维亚"
        case .provia100f: "普罗维亚"
        case .superia400: "超级"
        case .cinestill: "夜光"
        case .vision250d: "250D"
        case .hp5: "HP5"
        case .triX: "Tri-X"
        case .delta3200: "Delta"
        }
    }

    var descriptor: String {
        switch self {
        case .neutral: "不套用胶片色彩，保留 RAW 基础显影"
        case .portra: "奶油高光 · 柔和肤色"
        case .film135t: "深蓝天空 · 冷青阴影 · 高密度黑位"
        case .portra160: "低饱和肤色 · 细腻层次"
        case .portra800: "暖钨丝光 · 柔和高光"
        case .pro400h: "薄荷青绿 · 空气感"
        case .gold: "金色午后 · 饱满暖调"
        case .ektar100: "锐利细节 · 浓郁红蓝"
        case .classicChrome: "低饱和 · 深青阴影"
        case .velvia50: "高饱和 · 通透风光"
        case .provia100f: "自然浓郁 · 中性肤色"
        case .superia400: "青绿阴影 · 日常街拍"
        case .cinestill: "钨丝蓝 · 夜景红晕"
        case .vision250d: "柔和日光 · 电影宽容度"
        case .hp5: "银盐灰阶 · 粗粝颗粒"
        case .triX: "经典黑白 · 高反差"
        case .delta3200: "暗光银盐 · 强颗粒"
        }
    }

    var palette: [UInt32] {
        switch self {
        case .neutral: [0x8B8D8A, 0xB7B3A9, 0xDFD8CB]
        case .portra: [0xB86F58, 0xD6AA86, 0xEADCC7]
        case .film135t: [0x254B66, 0x4F8A86, 0xD8C0A2]
        case .portra160: [0xB77A66, 0xD9B08F, 0xEEE0CC]
        case .portra800: [0xAA614D, 0xD1A27C, 0xE8C8A9]
        case .pro400h: [0x5F7F79, 0xAABDB0, 0xDDDAC7]
        case .gold: [0xA84A31, 0xD79D54, 0xE9D3A2]
        case .ektar100: [0x8F3E34, 0xC47D56, 0x86A9A2]
        case .classicChrome: [0x344A49, 0x7F8B82, 0xB9B5A7]
        case .velvia50: [0x1F6654, 0xC95346, 0xE5B95E]
        case .provia100f: [0x315E63, 0x91A79A, 0xD4B78C]
        case .superia400: [0x3D765D, 0x8DB78A, 0xD4C8A6]
        case .cinestill: [0x2D5568, 0xB44E42, 0xD8B4A1]
        case .vision250d: [0x536F6B, 0xBE8B62, 0xD7C3A1]
        case .hp5: [0x2A2A28, 0x84817A, 0xD6D0C4]
        case .triX: [0x20201F, 0x6D6B66, 0xC5C0B6]
        case .delta3200: [0x292A29, 0x777A78, 0xCFCFC9]
        }
    }

    var isMonochrome: Bool {
        self == .hp5 || self == .triX || self == .delta3200
    }

    var factorySettings: FilmSettings {
        switch self {
        case .neutral:
            .init(exposure: 0, temperature: 6500, tint: 0,
                  highlights: 0, shadows: 0, whites: 0, blacks: 0,
                  contrast: 0, vibrance: 0, saturation: 0, clarity: 0,
                  fade: 0, grain: 0, vignette: 0, sharpness: 0)
        case .portra:
            .init(exposure: 0.12, temperature: 6900, tint: 5,
                  highlights: -8, shadows: 8, whites: -3, blacks: 5,
                  contrast: -8, vibrance: 5, saturation: -10, clarity: -4,
                  fade: 10, grain: 18, vignette: 10, sharpness: 5)
        case .film135t:
            .init(exposure: -0.03, temperature: 6100, tint: -5,
                  highlights: -12, shadows: -12, whites: 2, blacks: -8,
                  contrast: 16, vibrance: 3, saturation: -5, clarity: 4,
                  fade: 3, grain: 22, vignette: 18, sharpness: 11)
        case .portra160:
            .init(exposure: 0.08, temperature: 6800, tint: 3,
                  highlights: -6, shadows: 8, whites: -3, blacks: 4,
                  contrast: -4, vibrance: 4, saturation: -6, clarity: -2,
                  fade: 7, grain: 12, vignette: 8, sharpness: 4)
        case .portra800:
            .init(exposure: 0.16, temperature: 7000, tint: 5,
                  highlights: -10, shadows: 12, whites: -4, blacks: 7,
                  contrast: -10, vibrance: 7, saturation: -6, clarity: -4,
                  fade: 12, grain: 30, vignette: 14, sharpness: 3)
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
        case .ektar100:
            .init(exposure: 0.02, temperature: 6600, tint: 2,
                  highlights: -6, shadows: 4, whites: 4, blacks: 3,
                  contrast: 10, vibrance: 12, saturation: 8, clarity: 5,
                  fade: 3, grain: 10, vignette: 10, sharpness: 10)
        case .classicChrome:
            .init(exposure: -0.04, temperature: 6200, tint: 1,
                  highlights: -8, shadows: 4, whites: 4, blacks: 6,
                  contrast: 12, vibrance: -8, saturation: -28, clarity: 4,
                  fade: 5, grain: 14, vignette: 18, sharpness: 9)
        case .velvia50:
            .init(exposure: -0.06, temperature: 6100, tint: -2,
                  highlights: -3, shadows: -4, whites: 6, blacks: -2,
                  contrast: 20, vibrance: 18, saturation: 22, clarity: 10,
                  fade: 0, grain: 6, vignette: 22, sharpness: 16)
        case .provia100f:
            .init(exposure: 0, temperature: 6300, tint: 0,
                  highlights: -5, shadows: 2, whites: 3, blacks: 2,
                  contrast: 10, vibrance: 8, saturation: 4, clarity: 5,
                  fade: 2, grain: 5, vignette: 12, sharpness: 12)
        case .superia400:
            .init(exposure: 0.08, temperature: 7200, tint: 3,
                  highlights: -8, shadows: 6, whites: -2, blacks: 4,
                  contrast: 5, vibrance: 8, saturation: 5, clarity: 0,
                  fade: 8, grain: 24, vignette: 14, sharpness: 6)
        case .cinestill:
            .init(exposure: 0.10, temperature: 4750, tint: -8,
                  highlights: -5, shadows: 10, whites: -2, blacks: 4,
                  contrast: -4, vibrance: 8, saturation: 4, clarity: -2,
                  fade: 12, grain: 26, vignette: 22, sharpness: 2)
        case .vision250d:
            .init(exposure: 0.06, temperature: 6900, tint: 2,
                  highlights: -6, shadows: 8, whites: -2, blacks: 4,
                  contrast: 0, vibrance: 5, saturation: -2, clarity: 0,
                  fade: 8, grain: 16, vignette: 12, sharpness: 5)
        case .hp5:
            .init(exposure: 0.04, temperature: 6500, tint: 0,
                  highlights: -4, shadows: 8, whites: 0, blacks: 6,
                  contrast: 14, vibrance: 0, saturation: 0, clarity: 6,
                  fade: 8, grain: 36, vignette: 16, sharpness: 10)
        case .triX:
            .init(exposure: 0.05, temperature: 6500, tint: 0,
                  highlights: -6, shadows: 8, whites: 2, blacks: 5,
                  contrast: 12, vibrance: 0, saturation: 0, clarity: 8,
                  fade: 8, grain: 32, vignette: 18, sharpness: 12)
        case .delta3200:
            .init(exposure: 0.10, temperature: 6500, tint: 0,
                  highlights: -10, shadows: 12, whites: -3, blacks: 8,
                  contrast: 8, vibrance: 0, saturation: 0, clarity: 0,
                  fade: 12, grain: 45, vignette: 22, sharpness: 4)
        }
    }
}

struct FilmSettings: Equatable, Codable, Sendable {
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

struct PresetClipboard: Codable, Sendable {
    let version: Int
    let profile: FilmProfile
    let settings: FilmSettings
    let intensity: Double

    init(profile: FilmProfile, settings: FilmSettings, intensity: Double) {
        version = 1
        self.profile = profile
        self.settings = settings
        self.intensity = intensity
    }
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
