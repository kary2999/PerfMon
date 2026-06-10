import AppKit
import CoreGraphics

// 生成 1024x1024 火箭加速器图标 PNG（与 App 内 RocketLogo 同款造型）。
// 用法：swift tools/make-icon.swift <输出png路径>

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"
let S = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
    fatalError("cannot create context")
}
let s = CGFloat(S)
// 翻转 y，使分数坐标(y 向下)与 App 内 RocketLogo 一致。
func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: (1 - y) * s) }

// 徽章圆角矩形（留少量内边距，符合 app 图标观感）
let inset = s * 0.07
let rect = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
let radius = rect.width * 0.235
let badge = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

ctx.saveGState()
ctx.addPath(badge); ctx.clip()
let grad = CGGradient(colorsSpace: cs, colors: [
    NSColor(red: 1, green: 0.37, blue: 0.43, alpha: 1).cgColor,
    NSColor(red: 0.59, green: 0.46, blue: 0.98, alpha: 1).cgColor,
    NSColor(red: 0.36, green: 0.55, blue: 1, alpha: 1).cgColor] as CFArray,
    locations: [0, 0.5, 1])!
ctx.drawLinearGradient(grad, start: P(0.12, 0.12), end: P(0.88, 0.88), options: [])
ctx.restoreGState()

func fill(_ build: (CGMutablePath) -> Void, _ color: NSColor) {
    let p = CGMutablePath(); build(p)
    ctx.addPath(p); ctx.setFillColor(color.cgColor); ctx.fillPath()
}

// 尾焰
fill({ p in
    p.move(to: P(0.42, 0.64))
    p.addQuadCurve(to: P(0.58, 0.64), control: P(0.5, 0.93))
}, NSColor(red: 1, green: 0.7, blue: 0.25, alpha: 1))

// 尾翼
fill({ p in
    p.move(to: P(0.40, 0.52)); p.addLine(to: P(0.27, 0.67)); p.addLine(to: P(0.40, 0.64)); p.closeSubpath()
}, NSColor(white: 0.95, alpha: 1))
fill({ p in
    p.move(to: P(0.60, 0.52)); p.addLine(to: P(0.73, 0.67)); p.addLine(to: P(0.60, 0.64)); p.closeSubpath()
}, NSColor(white: 0.95, alpha: 1))

// 机身
fill({ p in
    p.move(to: P(0.5, 0.15))
    p.addQuadCurve(to: P(0.64, 0.45), control: P(0.65, 0.25))
    p.addLine(to: P(0.605, 0.65))
    p.addQuadCurve(to: P(0.395, 0.65), control: P(0.5, 0.72))
    p.addLine(to: P(0.36, 0.45))
    p.addQuadCurve(to: P(0.5, 0.15), control: P(0.35, 0.25))
    p.closeSubpath()
}, .white)

// 舷窗
fill({ p in
    p.addEllipse(in: CGRect(x: 0.42 * s, y: (1 - 0.47) * s, width: 0.16 * s, height: 0.16 * s))
}, NSColor(red: 0.36, green: 0.62, blue: 1, alpha: 1))

guard let cg = ctx.makeImage() else { fatalError("makeImage failed") }
let rep = NSBitmapImageRep(cgImage: cg)
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png failed") }
try! data.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
