import SwiftUI

/// 自绘「火箭加速器」logo：渐变圆角徽章 + 白色火箭 + 尾焰。替代 emoji。
struct RocketLogo: View {
    var size: CGFloat = 22

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * h) }

            // 徽章背景渐变
            let badge = Path(roundedRect: CGRect(x: 0, y: 0, width: w, height: h),
                             cornerRadius: w * 0.26)
            ctx.fill(badge, with: .linearGradient(
                Gradient(colors: [Color(red: 1, green: 0.37, blue: 0.43),
                                  Color(red: 0.59, green: 0.46, blue: 0.98),
                                  Color(red: 0.36, green: 0.55, blue: 1)]),
                startPoint: .zero, endPoint: CGPoint(x: w, y: h)))

            // 尾焰（橙黄）
            var flame = Path()
            flame.move(to: P(0.42, 0.64))
            flame.addQuadCurve(to: P(0.58, 0.64), control: P(0.5, 0.92))
            ctx.fill(flame, with: .linearGradient(
                Gradient(colors: [Color(red: 1, green: 0.85, blue: 0.3),
                                  Color(red: 1, green: 0.5, blue: 0.2)]),
                startPoint: P(0.5, 0.64), endPoint: P(0.5, 0.9)))

            // 左右尾翼
            var finL = Path()
            finL.move(to: P(0.40, 0.52)); finL.addLine(to: P(0.28, 0.66)); finL.addLine(to: P(0.40, 0.64))
            finL.closeSubpath()
            var finR = Path()
            finR.move(to: P(0.60, 0.52)); finR.addLine(to: P(0.72, 0.66)); finR.addLine(to: P(0.60, 0.64))
            finR.closeSubpath()
            ctx.fill(finL, with: .color(Color(red: 0.9, green: 0.93, blue: 1)))
            ctx.fill(finR, with: .color(Color(red: 0.9, green: 0.93, blue: 1)))

            // 机身（白色，上尖下圆）
            var body = Path()
            body.move(to: P(0.5, 0.16))                                   // 鼻尖
            body.addQuadCurve(to: P(0.63, 0.45), control: P(0.64, 0.26))  // 右肩
            body.addLine(to: P(0.60, 0.64))                               // 右下
            body.addQuadCurve(to: P(0.40, 0.64), control: P(0.5, 0.70))   // 底圆
            body.addLine(to: P(0.37, 0.45))                               // 左下
            body.addQuadCurve(to: P(0.5, 0.16), control: P(0.36, 0.26))   // 左肩
            body.closeSubpath()
            ctx.fill(body, with: .color(.white))

            // 舷窗（蓝）
            let win = Path(ellipseIn: CGRect(x: 0.43 * w, y: 0.34 * h, width: 0.14 * w, height: 0.14 * h))
            ctx.fill(win, with: .color(Color(red: 0.36, green: 0.62, blue: 1)))
        }
        .frame(width: size, height: size)
    }

    /// 渲染成 NSImage（用于菜单栏 NSStatusItem）。
    @MainActor func nsImage(scale: CGFloat = 2) -> NSImage? {
        let r = ImageRenderer(content: self)
        r.scale = scale
        return r.nsImage
    }
}
