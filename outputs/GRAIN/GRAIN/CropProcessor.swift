import CoreImage
import CoreText
import Foundation

enum CropProcessor {
    private static let context = CIContext(options: [.cacheIntermediates: false])

    static func apply(_ crop: CropTransform, to image: CGImage) -> CGImage {
        guard !crop.isIdentity else { return image }
        var output = CIImage(cgImage: image)

        if crop.flipHorizontal {
            output = oriented(output, scaleX: -1, scaleY: 1)
        }
        if crop.flipVertical {
            output = oriented(output, scaleX: 1, scaleY: -1)
        }

        let turns = ((crop.rotationQuarterTurns % 4) + 4) % 4
        if turns > 0 {
            output = output.transformed(
                by: CGAffineTransform(rotationAngle: -CGFloat(turns) * .pi / 2)
            )
            let extent = output.extent
            output = output.transformed(by: CGAffineTransform(translationX: -extent.minX, y: -extent.minY))
        }

        let extent = output.extent
        let cropRect = CGRect(
            x: extent.minX + extent.width * crop.normalizedX,
            y: extent.minY + extent.height * (1 - crop.normalizedY - crop.normalizedHeight),
            width: extent.width * crop.normalizedWidth,
            height: extent.height * crop.normalizedHeight
        ).integral.intersection(extent)
        let cropped = output.cropped(to: cropRect)
        let normalized = cropped.transformed(by: CGAffineTransform(translationX: -cropRect.minX, y: -cropRect.minY))
        return context.createCGImage(normalized, from: CGRect(origin: .zero, size: cropRect.size)) ?? image
    }

    private static func oriented(_ image: CIImage, scaleX: CGFloat, scaleY: CGFloat) -> CIImage {
        let flipped = image.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let newExtent = flipped.extent
        return flipped.transformed(
            by: CGAffineTransform(translationX: -newExtent.minX, y: -newExtent.minY)
        )
    }
}

enum TextOverlayRenderer {
    static func render(_ overlays: [PhotoTextOverlay], onto image: CGImage) -> CGImage {
        guard !overlays.isEmpty else { return image }
        let width = image.width
        let height = image.height
        let colorSpace = CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return image
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        for overlay in overlays where !overlay.text.isEmpty {
            let pointSize = max(8, CGFloat(overlay.fontSize) * CGFloat(min(width, height)))
            let fontName: String
            switch overlay.font {
            case .rounded: fontName = "AvenirNext-DemiBold"
            case .serif: fontName = "TimesNewRomanPS-BoldMT"
            case .monospaced: fontName = "Menlo-Bold"
            }
            let font = CTFontCreateWithName(fontName as CFString, pointSize, nil)
            let foreground = CGColor(
                colorSpace: colorSpace,
                components: [
                    CGFloat(overlay.red),
                    CGFloat(overlay.green),
                    CGFloat(overlay.blue),
                    CGFloat(overlay.alpha)
                ]
            ) ?? CGColor(gray: 1, alpha: 1)
            let attributes: [NSAttributedString.Key: Any] = [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): foreground
            ]
            let lines = overlay.text.components(separatedBy: .newlines)
            let lineHeight = pointSize * 1.18
            let totalHeight = lineHeight * CGFloat(max(lines.count, 1))
            let centerX = CGFloat(overlay.x) * CGFloat(width)
            let centerY = CGFloat(1 - overlay.y) * CGFloat(height)
            let topY = centerY + totalHeight / 2

            context.saveGState()
            context.textMatrix = .identity
            for (index, text) in lines.enumerated() {
                let line = CTLineCreateWithAttributedString(
                    NSAttributedString(string: text, attributes: attributes)
                )
                let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
                let x = centerX - bounds.width / 2 - bounds.minX
                let baseline = topY - lineHeight * (CGFloat(index) + 0.82)
                context.textPosition = CGPoint(x: x, y: baseline)
                CTLineDraw(line, context)
            }
            context.restoreGState()
        }
        return context.makeImage() ?? image
    }
}
