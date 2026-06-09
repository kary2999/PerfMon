import SwiftUI

struct SparklineView: View {
    var points: [Double]
    var color: Color
    var maxValue: Double = 100

    var body: some View {
        GeometryReader { geo in
            Path { p in
                guard points.count > 1 else { return }
                let stepX = geo.size.width / CGFloat(points.count - 1)
                for (i, v) in points.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = geo.size.height * (1 - CGFloat(min(v, maxValue) / maxValue))
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }.stroke(color, lineWidth: 2)
        }
    }
}
