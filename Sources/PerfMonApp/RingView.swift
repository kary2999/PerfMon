import SwiftUI

struct RingView: View {
    var value: Double
    var label: String
    var unit: String
    var color: Color
    var maxValue: Double = 100

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(1, value / maxValue))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                Text("\(Int(value))\(unit)").font(.system(size: 18, weight: .bold, design: .monospaced))
                Text(label).font(.system(size: 9)).foregroundColor(.white.opacity(0.55))
            }
        }.frame(width: 84, height: 84)
    }
}
