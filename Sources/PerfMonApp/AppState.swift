import Foundation
import SwiftUI
import Combine
import SensorKit

final class AppState: ObservableObject {
    @Published var metrics: Metrics = .empty
    @Published var cpuHistory: [Double] = []
    @Published var cpuTempHistory: [Double] = []

    private let kit = SensorKit()
    private var timer: Timer?

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    private func tick() {
        let m = kit.snapshot()
        metrics = m
        cpuHistory.append(Double(m.cpuPercent))
        if cpuHistory.count > 60 { cpuHistory.removeFirst() }
        if let t = m.temps.cpu {
            cpuTempHistory.append(t)
            if cpuTempHistory.count > 60 { cpuTempHistory.removeFirst() }
        }
    }
}
