import CoreGraphics
import Foundation

struct LookRecommendation: Sendable {
    let profile: FilmProfile
    let exposureDelta: Double
    let temperatureDelta: Double
}

enum LocalLookAdvisor {
    static func recommend(from image: CGImage) -> LookRecommendation {
        let width = 48
        let height = max(1, Int(Double(width) * Double(image.height) / Double(image.width)))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        pixels.withUnsafeMutableBytes { bytes in
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

        var totalLuminance = 0.0
        var totalSaturation = 0.0
        var totalRed = 0.0
        var totalGreen = 0.0
        var totalBlue = 0.0
        var shadowCount = 0
        var highlightCount = 0
        let sampleCount = width * height

        for index in stride(from: 0, to: pixels.count, by: 4) {
            let red = Double(pixels[index]) / 255
            let green = Double(pixels[index + 1]) / 255
            let blue = Double(pixels[index + 2]) / 255
            let maximum = max(red, green, blue)
            let minimum = min(red, green, blue)
            let luminance = red * 0.2126 + green * 0.7152 + blue * 0.0722
            let saturation = maximum > 0.001 ? (maximum - minimum) / maximum : 0

            totalRed += red
            totalGreen += green
            totalBlue += blue
            totalLuminance += luminance
            totalSaturation += saturation
            if luminance < 0.25 { shadowCount += 1 }
            if luminance > 0.78 { highlightCount += 1 }
        }

        let luminance = totalLuminance / Double(sampleCount)
        let saturation = totalSaturation / Double(sampleCount)
        let red = totalRed / Double(sampleCount)
        let green = totalGreen / Double(sampleCount)
        let blue = totalBlue / Double(sampleCount)
        let shadowRatio = Double(shadowCount) / Double(sampleCount)
        let highlightRatio = Double(highlightCount) / Double(sampleCount)

        let profile: FilmProfile
        if saturation < 0.055 {
            profile = .triX
        } else if luminance < 0.30 && saturation < 0.20 {
            profile = .delta3200
        } else if (blue > red * 1.10 || green > red * 1.08) && shadowRatio > 0.30 {
            profile = .film135t
        } else if saturation > 0.36 && luminance > 0.40 {
            profile = .velvia50
        } else if red > blue * 1.16 && luminance > 0.34 {
            profile = .gold
        } else if highlightRatio > 0.18 && saturation < 0.28 {
            profile = .portra160
        } else if saturation < 0.17 {
            profile = .classicChrome
        } else if luminance < 0.36 && highlightRatio > 0.07 {
            profile = .portra800
        } else {
            profile = .portra
        }

        let targetLuminance = 0.50
        let exposureDelta = log2(targetLuminance / max(luminance, 0.04)).clamped(to: -0.75...0.75)
        let temperatureDelta: Double
        if red > blue * 1.15 {
            temperatureDelta = -220
        } else if blue > red * 1.12 {
            temperatureDelta = 260
        } else {
            temperatureDelta = 0
        }

        return LookRecommendation(
            profile: profile,
            exposureDelta: exposureDelta,
            temperatureDelta: temperatureDelta
        )
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
