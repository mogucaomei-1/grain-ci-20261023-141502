import CoreImage
import Foundation
import ImageIO

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let context = CIContext(options: [
    .cacheIntermediates: false,
    .useSoftwareRenderer: true
])
let source = CGImageSourceCreateWithURL(input as CFURL, nil)!
let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)!
var image = CIImage(cgImage: cgImage)
print("loaded", image.extent)

func check(_ label: String, _ image: CIImage) {
    print(label, image.extent)
    if context.createCGImage(image, from: image.extent) == nil {
        print("FAILED", label)
        exit(1)
    }
}

check("loaded", image)
image = image.applyingFilter("CIColorControls", parameters: [
    kCIInputSaturationKey: 0.9,
    kCIInputContrastKey: 0.95
])
check("controls", image)
image = image.applyingFilter("CIToneCurve", parameters: [
    "inputPoint0": CIVector(x: 0, y: 0.05),
    "inputPoint1": CIVector(x: 0.25, y: 0.28),
    "inputPoint2": CIVector(x: 0.5, y: 0.5),
    "inputPoint3": CIVector(x: 0.75, y: 0.75),
    "inputPoint4": CIVector(x: 1, y: 1)
])
check("curve", image)
if let random = CIFilter(name: "CIRandomGenerator")?.outputImage {
    let noise = random
        .transformed(by: CGAffineTransform(scaleX: 1, y: 1))
        .applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.3, y: 0.3, z: 0.3, w: 0),
            "inputGVector": CIVector(x: 0.3, y: 0.3, z: 0.3, w: 0),
            "inputBVector": CIVector(x: 0.3, y: 0.3, z: 0.3, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.05)
        ])
        .cropped(to: image.extent)
    image = noise.applyingFilter("CISoftLightBlendMode", parameters: [
        kCIInputBackgroundImageKey: image
    ])
}
check("grain", image)
