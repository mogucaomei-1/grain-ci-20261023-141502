import AppKit

let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.09, blue: 0.08, alpha: 1),
    NSColor(calibratedRed: 0.20, green: 0.14, blue: 0.11, alpha: 1),
    NSColor(calibratedRed: 0.06, green: 0.06, blue: 0.05, alpha: 1)
])!
background.draw(in: NSRect(origin: .zero, size: size), relativeCenterPosition: NSPoint(x: 0.65, y: 0.72))

NSColor(calibratedRed: 0.94, green: 0.90, blue: 0.84, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 224, y: 224, width: 576, height: 576)).fill()

let arc = NSBezierPath()
arc.appendArc(withCenter: NSPoint(x: 512, y: 512), radius: 206, startAngle: 0, endAngle: 180, clockwise: false)
arc.lineWidth = 44
arc.lineCapStyle = .round
NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.07, alpha: 1).setStroke()
arc.stroke()

NSColor(calibratedRed: 0.85, green: 0.42, blue: 0.25, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 634, y: 548, width: 86, height: 86)).fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 82, weight: .heavy),
    .foregroundColor: NSColor(calibratedRed: 0.08, green: 0.08, blue: 0.07, alpha: 1),
    .kern: 16,
    .paragraphStyle: paragraph
]
NSString(string: "GRAIN").draw(
    in: NSRect(x: 184, y: 316, width: 656, height: 120),
    withAttributes: attributes
)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Unable to render icon")
}

let output = URL(fileURLWithPath: CommandLine.arguments[1])
try png.write(to: output)
