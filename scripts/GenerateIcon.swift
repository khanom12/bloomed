import AppKit

// Original working icon. System rendering supplies the platform's corner mask.
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
let representation = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024,
                                      bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false,
                                      isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
NSColor(red: 0.137, green: 0.388, blue: 0.294, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1024, height: 1024)).fill()
let baseFont = NSFont.systemFont(ofSize: 690, weight: .semibold)
let rounded = NSFont(descriptor: baseFont.fontDescriptor.withDesign(.rounded)!, size: 690)!
("b" as NSString).draw(at: NSPoint(x: 285, y: 115), withAttributes: [.font: rounded, .foregroundColor: NSColor(red: 0.967, green: 0.98, blue: 0.956, alpha: 1)])
let leaf = NSBezierPath()
leaf.move(to: NSPoint(x: 638, y: 735))
leaf.curve(to: NSPoint(x: 788, y: 864), controlPoint1: NSPoint(x: 635, y: 829), controlPoint2: NSPoint(x: 708, y: 879))
leaf.curve(to: NSPoint(x: 638, y: 735), controlPoint1: NSPoint(x: 791, y: 778), controlPoint2: NSPoint(x: 725, y: 733))
NSColor(red: 0.627, green: 0.835, blue: 0.686, alpha: 1).setFill()
leaf.fill()
NSGraphicsContext.restoreGraphicsState()
try representation.representation(using: .png, properties: [:])!.write(to: directory.appendingPathComponent("AppIcon.png"))
print("Generated original Bloomed working icon.")
