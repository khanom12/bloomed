import AppKit
import CoreText

// Original, reproducible vector artwork. Coordinates are measured in a top-left
// canvas. Font glyphs become outlines; the app has no custom-font dependency.
let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let exports = root.appendingPathComponent("Brand/v1/exports")
let assets = root.appendingPathComponent("Bloomed/Assets.xcassets")
try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)

struct Ink {
    let hex: String
    var color: CGColor {
        let n = UInt64(hex, radix: 16)!
        return CGColor(srgbRed: CGFloat(n >> 16 & 255) / 255,
                       green: CGFloat(n >> 8 & 255) / 255,
                       blue: CGFloat(n & 255) / 255, alpha: 1)
    }
}
let moss = Ink(hex: "23634B"), paper = Ink(hex: "F6F8F5")
let sage = Ink(hex: "A0D5AF"), dark = Ink(hex: "111B16"), ink = Ink(hex: "172B24")

struct Shape {
    var path: CGPath
    var fill: Ink? = nil
    var stroke: Ink? = nil
    var width: CGFloat = 0
    var bounds: CGRect { path.boundingBoxOfPath.insetBy(dx: -width / 2, dy: -width / 2) }
    func transformed(_ t: CGAffineTransform) -> Shape {
        var t = t
        return Shape(path: path.copy(using: &t)!, fill: fill, stroke: stroke,
                     width: width * sqrt(abs(t.a * t.d - t.b * t.c)))
    }
    func recolored(_ color: Ink) -> Shape {
        Shape(path: path, fill: fill == nil ? nil : color,
              stroke: stroke == nil ? nil : color, width: width)
    }
}
func line(_ path: CGPath, _ width: CGFloat = 3.2, _ color: Ink = moss) -> Shape {
    Shape(path: path, stroke: color, width: width)
}
func dot(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ color: Ink = moss) -> Shape {
    Shape(path: CGPath(ellipseIn: CGRect(x: x-radius, y: y-radius, width: radius*2, height: radius*2), transform: nil), fill: color)
}
func rectangle(_ rect: CGRect, _ color: Ink, radius: CGFloat = 0) -> Shape {
    Shape(path: CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil), fill: color)
}
func openLoop(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat, _ width: CGFloat = 3.2) -> Shape {
    let p = CGMutablePath()
    p.addArc(center: CGPoint(x: x, y: y), radius: radius,
             startAngle: -.pi * 75 / 180, endAngle: -.pi / 6, clockwise: true)
    return line(p, width)
}
let stem = CGMutablePath()
stem.move(to: CGPoint(x: 72, y: 48)); stem.addLine(to: CGPoint(x: 72, y: 152))
let mark = [line(stem, 24), openLoop(128, 152, 56, 24)]

let fontURL = root.appendingPathComponent("Brand/v1/source/Manrope-Variable.ttf")
guard CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil),
      let descriptors = CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor],
      let baseDescriptor = descriptors.first else {
    throw NSError(domain: "BrandFont", code: 1, userInfo: [NSLocalizedDescriptionKey: "The bundled Manrope font could not be opened."])
}
let descriptor = CTFontDescriptorCreateCopyWithAttributes(baseDescriptor, [
    kCTFontVariationAttribute: [NSNumber(value: 0x77676874): NSNumber(value: 550)]
] as CFDictionary)
let wordFont = CTFontCreateWithFontDescriptor(descriptor, 160, nil)
precondition((CTFontCopyPostScriptName(wordFont) as String).contains("Manrope"), "Do not silently substitute the logo typeface.")
func textPath(_ text: String, font: CTFont, tracking: CGFloat = 0) -> CGPath {
    let string = NSAttributedString(string: text, attributes: [
        NSAttributedString.Key(kCTFontAttributeName as String): font,
        .kern: tracking
    ])
    let line = CTLineCreateWithAttributedString(string)
    let output = CGMutablePath()
    for run in CTLineGetGlyphRuns(line) as! [CTRun] {
        let count = CTRunGetGlyphCount(run)
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var positions = [CGPoint](repeating: .zero, count: count)
        CTRunGetGlyphs(run, CFRange(location: 0, length: count), &glyphs)
        CTRunGetPositions(run, CFRange(location: 0, length: count), &positions)
        let runFont = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
        for i in 0..<count {
            if let glyph = CTFontCreatePathForGlyph(runFont, glyphs[i], nil) {
                let t = CGAffineTransform(a: 1, b: 0, c: 0, d: -1,
                                          tx: positions[i].x, ty: -positions[i].y)
                output.addPath(glyph, transform: t)
            }
        }
    }
    return output
}
let smallMark = mark.map { $0.transformed(CGAffineTransform(scaleX: 0.8, y: 0.8)) }
let markBounds = smallMark.map(\.bounds).reduce(CGRect.null) { $0.union($1) }
let lettering = textPath("bloomed", font: wordFont, tracking: -1.2)
let textBounds = lettering.boundingBoxOfPath
let textTransform = CGAffineTransform(translationX: markBounds.maxX + 44 - textBounds.minX,
                                     y: markBounds.midY - textBounds.midY + 1)
var lockup = smallMark + [Shape(path: lettering, fill: moss).transformed(textTransform)]
let lockupBounds = lockup.map(\.bounds).reduce(CGRect.null) { $0.union($1) }.insetBy(dx: -12, dy: -12)
lockup = lockup.map { $0.transformed(CGAffineTransform(translationX: -lockupBounds.minX, y: -lockupBounds.minY)) }
let lockupSize = lockupBounds.size

// Companion artwork uses the same round-ended, open-curve grammar. It is
// decorative, never a chart, balance, reward state, or verification symbol.
let route = CGMutablePath()
route.move(to: CGPoint(x: 16, y: 55))
route.addCurve(to: CGPoint(x: 47, y: 39), control1: CGPoint(x: 52, y: 65), control2: CGPoint(x: 21, y: 32))
route.addCurve(to: CGPoint(x: 88, y: 18), control1: CGPoint(x: 85, y: 49), control2: CGPoint(x: 54, y: 12))
let walking = [line(route), dot(16,55,3.8), dot(88,18,5.2)]
let progress = [openLoop(25,49,10), openLoop(57,39,16), openLoop(96,28,22)]
let support = [openLoop(43,36,21), openLoop(78,36,21)]

func draw(_ shapes: [Shape], in context: CGContext) {
    context.setLineCap(.round); context.setLineJoin(.round)
    for shape in shapes {
        context.addPath(shape.path)
        if let fill = shape.fill { context.setFillColor(fill.color); context.fillPath() }
        else if let stroke = shape.stroke {
            context.setStrokeColor(stroke.color); context.setLineWidth(shape.width); context.strokePath()
        }
    }
}
func svgPath(_ path: CGPath) -> String {
    var pieces: [String] = []
    func n(_ p: CGPoint) -> String { String(format: "%.3f %.3f", Double(p.x), Double(p.y)) }
    path.applyWithBlock { p in
        let e = p.pointee
        switch e.type {
        case .moveToPoint: pieces.append("M\(n(e.points[0]))")
        case .addLineToPoint: pieces.append("L\(n(e.points[0]))")
        case .addQuadCurveToPoint: pieces.append("Q\(n(e.points[0])) \(n(e.points[1]))")
        case .addCurveToPoint: pieces.append("C\(n(e.points[0])) \(n(e.points[1])) \(n(e.points[2]))")
        case .closeSubpath: pieces.append("Z")
        @unknown default: break
        }
    }
    return pieces.joined(separator: " ")
}
func export(_ name: String, size: CGSize, shapes: [Shape], pngScale: CGFloat = 4, catalog: String? = nil, opaque: Bool = false) throws {
    let elements = shapes.map { shape in
        let style = shape.fill.map { "fill=\"#\($0.hex)\"" } ?? "fill=\"none\" stroke=\"#\(shape.stroke!.hex)\" stroke-width=\"\(shape.width)\" stroke-linecap=\"round\" stroke-linejoin=\"round\""
        return "<path d=\"\(svgPath(shape.path))\" \(style)/>"
    }.joined(separator: "\n")
    let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(size.width) \(size.height)\" width=\"\(size.width)\" height=\"\(size.height)\">\n\(elements)\n</svg>\n"
    try svg.write(to: exports.appendingPathComponent("\(name).svg"), atomically: true, encoding: .utf8)
    var media = CGRect(origin: .zero, size: size)
    let pdfURL = exports.appendingPathComponent("\(name).pdf")
    let pdf = CGContext(pdfURL as CFURL, mediaBox: &media, nil)!
    pdf.beginPDFPage(nil); pdf.translateBy(x: 0, y: size.height); pdf.scaleBy(x: 1, y: -1)
    draw(shapes, in: pdf); pdf.endPDFPage(); pdf.closePDF()
    let width = Int(ceil(size.width * pngScale)), height = Int(ceil(size.height * pngScale))
    let alpha = opaque ? CGImageAlphaInfo.noneSkipLast : .premultipliedLast
    let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                            bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: alpha.rawValue)!
    context.scaleBy(x: pngScale, y: pngScale); context.translateBy(x: 0, y: size.height); context.scaleBy(x: 1, y: -1)
    draw(shapes, in: context)
    let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
    let png = try bitmap.representation(using: .png, properties: [:]).unwrap()
    try png.write(to: exports.appendingPathComponent("\(name).png"))
    if let catalog {
        let directory = assets.appendingPathComponent("\(catalog).imageset")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = directory.appendingPathComponent("\(catalog).pdf")
        if FileManager.default.fileExists(atPath: destination.path) { try FileManager.default.removeItem(at: destination) }
        try FileManager.default.copyItem(at: pdfURL, to: destination)
        let json: [String: Any] = ["images": [["filename": "\(catalog).pdf", "idiom": "universal"]],
            "info": ["author": "xcode", "version": 1],
            "properties": ["preserves-vector-representation": true, "template-rendering-intent": "template"]]
        try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("Contents.json"))
    }
}
extension Optional {
    func unwrap() throws -> Wrapped { guard let value = self else { throw NSError(domain: "BrandExport", code: 1) }; return value }
}

try export("bloomed-mark-moss", size: CGSize(width:256,height:256), shapes:mark, catalog:"BloomedMark")
try export("bloomed-mark-paper", size: CGSize(width:256,height:256), shapes:mark.map { $0.recolored(paper) })
try export("bloomed-mark-sage", size: CGSize(width:256,height:256), shapes:mark.map { $0.recolored(sage) })
try export("bloomed-lockup-moss", size:lockupSize, shapes:lockup, catalog:"BloomedLockup")
try export("bloomed-lockup-paper", size:lockupSize, shapes:lockup.map { $0.recolored(paper) })
try export("bloomed-lockup-sage", size:lockupSize, shapes:lockup.map { $0.recolored(sage) })
try export("walking-route", size:CGSize(width:120,height:72), shapes:walking, catalog:"WalkingRoute")
try export("growing-loops", size:CGSize(width:128,height:72), shapes:progress, catalog:"GrowingLoops")
try export("support-pair", size:CGSize(width:120,height:72), shapes:support, catalog:"SupportPair")
let iconShapes = [rectangle(CGRect(x:0,y:0,width:1024,height:1024),moss)] + mark.map { $0.recolored(paper).transformed(CGAffineTransform(scaleX:4,y:4)) }
try export("bloomed-app-icon", size:CGSize(width:1024,height:1024), shapes:iconShapes, pngScale:1, opaque:true)
let iconDirectory = assets.appendingPathComponent("AppIcon.appiconset")
try Data(contentsOf:exports.appendingPathComponent("bloomed-app-icon.png")).write(to:iconDirectory.appendingPathComponent("AppIcon.png"))

// A review sheet, not an application screen. All artwork is drawn from the same paths.
var sheet = [rectangle(CGRect(x:0,y:0,width:1440,height:1040),paper)]
func sheetLabel(_ text:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ color:Ink = ink) {
    let f = CTFontCreateWithName("HelveticaNeue" as CFString,size,nil)
    let p = textPath(text,font:f,tracking:0.4)
    sheet.append(Shape(path:p,fill:color).transformed(CGAffineTransform(translationX:x,y:y)))
}
sheetLabel("BLOOMED  /  OPEN LOOP",80,72,15,moss)
let logoScale = 800 / lockupSize.width
sheet += lockup.map { $0.transformed(CGAffineTransform(a:logoScale,b:0,c:0,d:logoScale,tx:80,ty:140)) }
sheetLabel("A little each day.",83,365,26)
let panelY:CGFloat = 438
for x:CGFloat in [80,520,960] { sheet.append(rectangle(CGRect(x:x,y:panelY,width:400,height:342),Ink(hex:"FFFFFF"),radius:24)) }
sheetLabel("01  APP ICON",112,480,13,moss)
sheet.append(rectangle(CGRect(x:172,y:525,width:212,height:212),moss,radius:46))
sheet += mark.map { $0.recolored(paper).transformed(CGAffineTransform(a:212/256,b:0,c:0,d:212/256,tx:172,ty:525)) }
sheetLabel("02  SMALL BY DESIGN",552,480,13,moss)
for (i,size) in [32.0,56.0,88.0].enumerated() {
    sheet += mark.map { $0.transformed(CGAffineTransform(a:size/256,b:0,c:0,d:size/256,tx:560+CGFloat(i)*106,ty:594-size/2)) }
}
sheetLabel("03  A SHARED VISUAL LANGUAGE",992,480,12,moss)
sheet += walking.map { $0.transformed(CGAffineTransform(a:1.5,b:0,c:0,d:1.5,tx:1067,ty:510)) }
sheet += progress.map { $0.transformed(CGAffineTransform(a:0.95,b:0,c:0,d:0.95,tx:999,ty:662)) }
sheet += support.map { $0.transformed(CGAffineTransform(a:0.95,b:0,c:0,d:0.95,tx:1213,ty:662)) }
let colors = [moss,ink,sage,Ink(hex:"E8F1EB"),paper,dark]
for (i,color) in colors.enumerated() {
    let x:CGFloat = 80+CGFloat(i)*216
    sheet.append(rectangle(CGRect(x:x,y:842,width:192,height:64),color,radius:12))
    if i >= 3 && i <= 4 {
        sheet.append(Shape(path:CGPath(roundedRect:CGRect(x:x,y:842,width:192,height:64),cornerWidth:12,cornerHeight:12,transform:nil),stroke:Ink(hex:"D7E1D9"),width:1))
    }
    sheetLabel("#\(color.hex)",x,939,14)
}
sheetLabel("Vector originals  /  Single-color marks  /  Native light & dark appearance",80,1000,14,moss)
try export("bloomed-brand-sheet",size:CGSize(width:1440,height:1040),shapes:sheet,pngScale:1.5,opaque:true)
let manifest: [String:Any] = ["lockupAspectRatio":lockupSize.width/lockupSize.height,
    "wordmarkFont":"Manrope", "wordmarkWeight":550, "wordmarkTracking":-1.2,
    "markViewBox":[0,0,256,256], "markStroke":24, "version":1]
try JSONSerialization.data(withJSONObject:manifest,options:[.prettyPrinted,.sortedKeys]).write(to:exports.appendingPathComponent("brand-manifest.json"))
print("Exported brand kit. Lockup aspect ratio: \(lockupSize.width/lockupSize.height). Typeface: \(CTFontCopyPostScriptName(wordFont)).")
