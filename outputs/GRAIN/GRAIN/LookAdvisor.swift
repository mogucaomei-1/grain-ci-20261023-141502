import CoreGraphics
import Foundation

struct LookRecommendation: Sendable {
    let profile: FilmProfile
    let settings: FilmSettings
    let intensity: Double
    let reason: String
}

struct RGBHistogram: Sendable {
    let red: [Double]
    let green: [Double]
    let blue: [Double]
    let luminance: [Double]
}

enum LocalLookAdvisor {
    static func recommend(from image: CGImage) -> LookRecommendation {
        let sample = ImageSample(image: image, width: 64)

        let p10 = sample.percentile(0.10)
        let p50 = sample.percentile(0.50)
        let p90 = sample.percentile(0.90)
        let tonalRange = p90 - p10

        let scene: FilmProfile
        let sceneReason: String
        if sample.saturation < 0.045 {
            scene = .triX
            sceneReason = "低饱和画面"
        } else if sample.luminance < 0.24 && sample.saturation > 0.16 {
            scene = .cinestill
            sceneReason = "暗光环境"
        } else if sample.skinRatio > 0.13 {
            scene = sample.luminance > 0.57 ? .portra160 : .portra
            sceneReason = "中心区域检测到人物肤色"
        } else if sample.blue > sample.red * 1.10 && sample.shadowRatio > 0.30 {
            scene = .film135t
            sceneReason = "冷青阴影与城市色调"
        } else if sample.green > sample.red * 1.04 && sample.saturation > 0.20 {
            scene = sample.saturation > 0.39 ? .velvia50 : .superia400
            sceneReason = "绿色植被占主导"
        } else if sample.red > sample.blue * 1.17 {
            scene = .gold
            sceneReason = "暖色主导"
        } else if sample.highlightRatio > 0.17 && tonalRange > 0.60 {
            scene = .portra160
            sceneReason = "高光丰富且层次柔和"
        } else if sample.saturation < 0.15 {
            scene = .classicChrome
            sceneReason = "低饱和灰调画面"
        } else if sample.luminance < 0.34 {
            scene = .portra800
            sceneReason = "偏暗且光线柔和"
        } else if sample.saturation > 0.27 && tonalRange > 0.62 {
            scene = .ektar100
            sceneReason = "细节丰富且色彩明确"
        } else {
            scene = .provia100f
            sceneReason = "自然日光与均衡层次"
        }

        var settings = scene.factorySettings
        let targetLuminance = 0.50
        settings.exposure += log2(targetLuminance / max(p50, 0.04)).clamped(to: -0.85...0.85)

        if sample.shadowRatio > 0.34 {
            settings.shadows += 12
            settings.blacks += 5
        } else if sample.shadowRatio < 0.08 {
            settings.shadows -= 5
            settings.blacks -= 3
        }
        if sample.highlightRatio > 0.13 {
            settings.highlights -= 12
            settings.whites -= 5
        }
        if tonalRange < 0.38 {
            settings.contrast += 12
        } else if tonalRange > 0.72 {
            settings.contrast -= 7
        }
        if sample.saturation < 0.16 {
            settings.vibrance += 12
        } else if sample.saturation > 0.38 {
            settings.vibrance -= 5
            settings.saturation -= 4
        }
        if sample.red > sample.blue * 1.12 {
            settings.temperature -= 260
        } else if sample.blue > sample.red * 1.12 {
            settings.temperature += 260
        }
        if sample.green > (sample.red + sample.blue) * 0.54 {
            settings.tint += 6
        }
        if sample.edgeEnergy < 0.035 {
            settings.clarity += 8
            settings.sharpness += 5
        } else if sample.edgeEnergy > 0.16 {
            settings.clarity -= 4
        }

        settings.exposure = settings.exposure.clamped(to: -2...2)
        settings.temperature = settings.temperature.clamped(to: 3500...9000)
        settings.tint = settings.tint.clamped(to: -100...100)
        settings.highlights = settings.highlights.clamped(to: -100...100)
        settings.shadows = settings.shadows.clamped(to: -100...100)
        settings.whites = settings.whites.clamped(to: -100...100)
        settings.blacks = settings.blacks.clamped(to: -100...100)
        settings.contrast = settings.contrast.clamped(to: -100...100)
        settings.vibrance = settings.vibrance.clamped(to: -100...100)
        settings.saturation = settings.saturation.clamped(to: -100...100)
        settings.clarity = settings.clarity.clamped(to: -100...100)
        settings.sharpness = settings.sharpness.clamped(to: 0...100)

        let adjustmentNotes = [
            sample.shadowRatio > 0.34 ? "提亮阴影" : nil,
            sample.highlightRatio > 0.13 ? "压低高光" : nil,
            tonalRange < 0.38 ? "补充对比" : nil,
            sample.saturation < 0.16 ? "增强色彩" : nil
        ].compactMap { $0 }
        let reason = ([sceneReason] + adjustmentNotes.prefix(2)).joined(separator: " · ")

        return LookRecommendation(
            profile: scene,
            settings: settings,
            intensity: 0.86,
            reason: reason
        )
    }

    static func histogram(from image: CGImage) -> RGBHistogram {
        let sample = ImageSample(image: image, width: 72)
        let binCount = 40
        var red = [Double](repeating: 0, count: binCount)
        var green = [Double](repeating: 0, count: binCount)
        var blue = [Double](repeating: 0, count: binCount)
        var luminance = [Double](repeating: 0, count: binCount)

        for index in sample.rgbOffsets {
            let r = Double(sample.pixels[index]) / 255
            let g = Double(sample.pixels[index + 1]) / 255
            let b = Double(sample.pixels[index + 2]) / 255
            let luma = r * 0.2126 + g * 0.7152 + b * 0.0722
            red[min(Int(r * Double(binCount - 1)), binCount - 1)] += 1
            green[min(Int(g * Double(binCount - 1)), binCount - 1)] += 1
            blue[min(Int(b * Double(binCount - 1)), binCount - 1)] += 1
            luminance[min(Int(luma * Double(binCount - 1)), binCount - 1)] += 1
        }

        func normalized(_ values: [Double]) -> [Double] {
            let maximum = max(values.max() ?? 1, 1)
            return values.map { $0 / maximum }
        }
        return RGBHistogram(
            red: normalized(red),
            green: normalized(green),
            blue: normalized(blue),
            luminance: normalized(luminance)
        )
    }
}

private struct ImageSample {
    let pixels: [UInt8]
    let rgbOffsets: StrideTo<Int>
    let luminanceValues: [Double]
    let luminance: Double
    let saturation: Double
    let red: Double
    let green: Double
    let blue: Double
    let shadowRatio: Double
    let highlightRatio: Double
    let skinRatio: Double
    let edgeEnergy: Double

    init(image: CGImage, width: Int) {
        let height = max(1, Int(Double(width) * Double(image.height) / Double(image.width)))
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        buffer.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        pixels = buffer
        rgbOffsets = stride(from: 0, to: buffer.count, by: 4)

        var lumValues: [Double] = []
        lumValues.reserveCapacity(width * height)
        var totalR = 0.0
        var totalG = 0.0
        var totalB = 0.0
        var totalSaturation = 0.0
        var shadowCount = 0
        var highlightCount = 0
        var skinCount = 0
        var edgeTotal = 0.0

        for index in rgbOffsets {
            let r = Double(buffer[index]) / 255
            let g = Double(buffer[index + 1]) / 255
            let b = Double(buffer[index + 2]) / 255
            let maximum = max(r, g, b)
            let minimum = min(r, g, b)
            let luma = r * 0.2126 + g * 0.7152 + b * 0.0722
            lumValues.append(luma)
            totalR += r
            totalG += g
            totalB += b
            totalSaturation += maximum > 0.001 ? (maximum - minimum) / maximum : 0
            if luma < 0.25 { shadowCount += 1 }
            if luma > 0.78 { highlightCount += 1 }
            let pixelIndex = index / 4
            let x = pixelIndex % width
            let y = pixelIndex / width
            let isNearCenter = x >= width / 4 && x <= width * 3 / 4
                && y >= height / 5 && y <= height * 4 / 5
            let cb = 128 - 0.168736 * r * 255 - 0.331264 * g * 255 + 0.5 * b * 255
            let cr = 128 + 0.5 * r * 255 - 0.418688 * g * 255 - 0.081312 * b * 255
            if isNearCenter,
               cb >= 76, cb <= 128,
               cr >= 133, cr <= 176,
               luma > 0.15 {
                skinCount += 1
            }
        }

        let count = Double(width * height)
        luminance = lumValues.reduce(0, +) / count
        saturation = totalSaturation / count
        red = totalR / count
        green = totalG / count
        blue = totalB / count
        shadowRatio = Double(shadowCount) / count
        highlightRatio = Double(highlightCount) / count
        skinRatio = Double(skinCount) / count
        luminanceValues = lumValues.sorted()

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let current = Double(buffer[index]) + Double(buffer[index + 1]) + Double(buffer[index + 2])
                if x + 1 < width {
                    let right = Double(buffer[index + 4]) + Double(buffer[index + 5]) + Double(buffer[index + 6])
                    edgeTotal += abs(current - right) / 765
                }
                if y + 1 < height {
                    let below = Double(buffer[index + width * 4]) + Double(buffer[index + width * 4 + 1]) + Double(buffer[index + width * 4 + 2])
                    edgeTotal += abs(current - below) / 765
                }
            }
        }
        edgeEnergy = edgeTotal / count
    }

    func percentile(_ percentile: Double) -> Double {
        guard !luminanceValues.isEmpty else { return 0.5 }
        let index = Int((Double(luminanceValues.count - 1) * percentile).rounded())
        return luminanceValues[index]
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
