import SwiftUI

struct TempGaugeView: View {
    var title: String
    var value: Double?         // nil → 不可用
    var history: [Double]

    private var color: Color {
        guard let v = value else { return .gray }
        if v >= 80 { return Color(red: 1, green: 0.37, blue: 0.31) }
        if v >= 65 { return Color(red: 1, green: 0.83, blue: 0.47) }
        return Color(red: 0.48, green: 0.94, blue: 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🌡 \(title)").font(.system(size: 11)).foregroundColor(.white.opacity(0.6))
            if let v = value {
                Text("\(Int(v))°C").font(.system(size: 26, weight: .bold)).foregroundColor(color)
                SparklineView(points: history, color: color, maxValue: 100).frame(height: 24)
            } else {
                Text("不可用").font(.system(size: 16, weight: .semibold)).foregroundColor(.white.opacity(0.4))
                Text("此芯片暂未适配温度传感器").font(.system(size: 9)).foregroundColor(.white.opacity(0.35))
            }
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .cornerRadius(12)
    }
}
