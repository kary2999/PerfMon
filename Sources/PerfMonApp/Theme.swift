import SwiftUI

/// 统一配色：随数值在 青→黄→红 之间取色。
enum Theme {
    static let cool = Color(red: 0.48, green: 0.94, blue: 1)
    static let warm = Color(red: 1, green: 0.83, blue: 0.47)
    static let hot  = Color(red: 1, green: 0.37, blue: 0.31)
    static let good = Color(red: 0.49, green: 0.82, blue: 0.40)

    static func byLoad(_ p: Int) -> Color {
        if p >= 80 { return hot }
        if p >= 50 { return warm }
        return cool
    }
    static func byTemp(_ v: Double) -> Color {
        if v >= 80 { return hot }
        if v >= 65 { return warm }
        return cool
    }
    static func card<V: View>(_ content: V) -> some View {
        content.padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.07))
            .cornerRadius(12)
    }
}
