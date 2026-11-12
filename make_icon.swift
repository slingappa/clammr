// make_icon.swift — draws the Clammr app icon (original artwork) to a 1024x1024 PNG.
// Usage: swift make_icon.swift out.png
// Concept: a scallop shell as the laptop lid, sitting on a laptop base ("clamshell").
import AppKit

let S: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "icon_1024.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
func linear(_ c: [CGColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: c as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [])
}

// 1. Background: macOS-style rounded square, deep-sea gradient.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(tilePath); ctx.setFillColor(rgb(0x123150)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(tilePath); ctx.clip()
linear([rgb(0x2B6C8F), rgb(0x0E2740)], from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
ctx.restoreGState()

// 2. Laptop base (keyboard deck).
let base = CGMutablePath()
base.move(to: CGPoint(x: 196, y: 318))
base.addLine(to: CGPoint(x: 828, y: 318))
base.addQuadCurve(to: CGPoint(x: 800, y: 262), control: CGPoint(x: 842, y: 270))
base.addLine(to: CGPoint(x: 224, y: 262))
base.addQuadCurve(to: CGPoint(x: 196, y: 318), control: CGPoint(x: 182, y: 270))
base.closeSubpath()
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: rgb(0x000000, 0.4))
ctx.addPath(base); ctx.setFillColor(rgb(0xD8DEE6)); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(base); ctx.clip()
linear([rgb(0xF2F5F8), rgb(0xA9B4C2)], from: CGPoint(x: 512, y: 318), to: CGPoint(x: 512, y: 262))
ctx.restoreGState()
// trackpad notch
ctx.addPath(CGPath(roundedRect: CGRect(x: 452, y: 304, width: 120, height: 14), cornerWidth: 7, cornerHeight: 7, transform: nil))
ctx.setFillColor(rgb(0x8C98A8)); ctx.fillPath()

// 3. Scallop-shell lid, hinged at centre of the base.
let hinge = CGPoint(x: 512, y: 330)
let R: CGFloat = 430, a0: CGFloat = .pi * 0.17, a1: CGFloat = .pi * 0.83
let lobes: CGFloat = 7
func edge(_ t: CGFloat) -> CGPoint {            // t in 0...1 across the fan
    let th = a0 + (a1 - a0) * t
    let r = R - 26 * (1 - abs(sin(lobes * .pi * t)))   // scalloped rim
    return CGPoint(x: hinge.x + r * cos(th), y: hinge.y + r * sin(th))
}
let shell = CGMutablePath()
shell.move(to: hinge)
for i in 0...400 { shell.addLine(to: edge(CGFloat(i) / 400)) }
shell.closeSubpath()

// "ears" at the hinge, classic scallop detail
let ears = CGMutablePath()
ears.move(to: CGPoint(x: hinge.x - 92, y: hinge.y + 4))
ears.addLine(to: CGPoint(x: hinge.x + 92, y: hinge.y + 4))
ears.addLine(to: CGPoint(x: hinge.x + 58, y: hinge.y + 92))
ears.addLine(to: CGPoint(x: hinge.x - 58, y: hinge.y + 92))
ears.closeSubpath()

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0x000000, 0.45))
ctx.addPath(shell); ctx.addPath(ears); ctx.setFillColor(rgb(0xF0D9C0)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(shell); ctx.addPath(ears); ctx.clip()
// pearly gradient
linear([rgb(0xFFF3E6), rgb(0xF6C9A4), rgb(0xE29A7A)],
       from: CGPoint(x: 512, y: hinge.y + R), to: hinge)
// radial ribs, one per lobe peak
ctx.setLineCap(.round)
for k in 0..<Int(lobes) {
    let t = (CGFloat(k) + 0.5) / lobes
    let p = edge(t)
    ctx.move(to: CGPoint(x: hinge.x, y: hinge.y + 30)); ctx.addLine(to: p)
}
ctx.setStrokeColor(rgb(0xB8654A, 0.55)); ctx.setLineWidth(14); ctx.strokePath()
// growth rings
for r in stride(from: CGFloat(140), through: 360, by: 110) {
    ctx.addArc(center: hinge, radius: r, startAngle: a0, endAngle: a1, clockwise: false)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.28)); ctx.setLineWidth(6); ctx.strokePath()
}
ctx.restoreGState()

// rim outline
ctx.addPath(shell); ctx.setStrokeColor(rgb(0xB8654A, 0.6)); ctx.setLineWidth(6); ctx.strokePath()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
