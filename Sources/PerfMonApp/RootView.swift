import SwiftUI

enum Tab: String, CaseIterable {
    case overview = "总览"
    case process = "进程"
    case boost = "优化"
    case diagnosis = "诊断"
    case history = "历史"
}

struct RootView: View {
    @ObservedObject var state: AppState
    @State private var tab: Tab = .overview

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标签栏
            HStack(spacing: 6) {
                RocketLogo(size: 16)
                ForEach(Tab.allCases, id: \.self) { t in
                    Text(t.rawValue)
                        .font(.system(size: 12, weight: tab == t ? .semibold : .regular))
                        .foregroundColor(tab == t ? .white : .white.opacity(0.55))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(tab == t ? Color.white.opacity(0.16) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                        .onTapGesture { tab = t }
                }
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 9)
            .background(Color.white.opacity(0.05))

            Group {
                switch tab {
                case .overview: OverviewView(state: state)
                case .process: ProcessView(state: state)
                case .boost: BoostView(state: state)
                case .diagnosis: DiagnosisView(state: state)
                case .history: HistoryView(state: state)
                }
            }
        }
        .frame(width: 480, height: 408)
    }
}
