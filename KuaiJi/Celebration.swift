//
//  Celebration.swift
//  KuaiJi
//
//  Global confetti celebration overlay using CAEmitterLayer.
//

import SwiftUI
import Combine
import UIKit

@MainActor
final class CelebrationManager: ObservableObject {
    static let shared = CelebrationManager()
    @Published var isShowing = false

    func trigger(duration: TimeInterval = 10) {
        guard !isShowing else { return }
        isShowing = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            withAnimation(.easeOut(duration: 0.25)) { self.isShowing = false }
        }
    }
}

struct CelebrationOverlay: View {
    @ObservedObject var manager: CelebrationManager

    var body: some View {
        Group {
            if manager.isShowing {
                ZStack {
                    Color.black.opacity(0.01) // allow taps to pass through
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    ConfettiEmitterView()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    VStack {
                        Spacer()
                        
                        // 使用 ZStack 来实现描边效果
                        ZStack {
                            // 1. 描边层 (使用 Color.appSuccess)
                            Text(L.supportSuccess.localized)
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.appSuccess) // <-- 描边颜色
                                // 调整偏移量来控制描边厚度/可见性
                                .offset(x: 1.5, y: 1.5)
                            
                            // 2. 填充层 (使用黑色)
                            Text(L.supportSuccess.localized)
                                .font(.system(size: 30, weight: .semibold, design: .rounded))
                                .foregroundStyle(.black) // <-- 填充颜色（黑色）
                        }
                        
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
                .transition(.opacity)
            }
        }
    }
}

private struct ConfettiEmitterView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: -10)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width, height: 1)
        emitter.birthRate = 1

        let colors: [UIColor] = [
            UIColor.systemPink,
            UIColor.systemTeal,
            UIColor.systemYellow,
            UIColor.systemGreen,
            UIColor.systemOrange,
            UIColor.systemPurple
        ]

        var cells: [CAEmitterCell] = []
        for color in colors {
            let cell = CAEmitterCell()
            cell.birthRate = 12
            cell.lifetime = 6
            cell.velocity = 180
            cell.velocityRange = 80
            cell.emissionLongitude = .pi
            cell.emissionRange = .pi / 6
            cell.spin = 3.5
            cell.spinRange = 4
            cell.scale = 0.6
            cell.scaleRange = 0.3
            cell.contents = makeConfettiImage(color: color).cgImage
            cells.append(cell)
        }
        emitter.emitterCells = cells
        view.layer.addSublayer(emitter)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private func makeConfettiImage(color: UIColor) -> UIImage {
        let size = CGSize(width: 10, height: 14)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let path = UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 2)
            color.setFill()
            path.fill()
        }
    }
}


