//
//  Celebration.swift
//  KuaiJi
//
//  Global confetti celebration overlay using CAEmitterLayer.
//

import SwiftUI
import Combine
import UIKit

// MARK: - Manager Class
@MainActor
final class CelebrationManager: ObservableObject {
    static let shared = CelebrationManager()
    @Published var isShowing = false

    func trigger(duration: TimeInterval = 5.0) {
        guard !isShowing else { return }
        
        // 触觉反馈
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
        
        isShowing = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            withAnimation(.easeOut(duration: 0.5)) { self.isShowing = false }
        }
    }
}

// MARK: - Overlay View
struct CelebrationOverlay: View {
    @ObservedObject var manager: CelebrationManager
    
    // 整个卡片的进场动画状态
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0
    @State private var rotation: Double = -10

    var body: some View {
        Group {
            if manager.isShowing {
                ZStack {
                    // 1. 背景层
                    Color.black.opacity(0.2)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    
                    // 2. 纸屑层
                    ConfettiEmitterView()
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    
                    // 3. 核心提示卡片 (纯文字版)
                    VStack {
                        Text(L.supportSuccess.localized)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                    // 修改这里：使用系统背景色代替毛玻璃材质
                    .background(Color(UIColor.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                    
                    // --- 布局位置调整 ---
                    .offset(y: -UIScreen.main.bounds.height * 0.3)
                    
                    // 卡片整体进场效果
                    .scaleEffect(scale)
                    .opacity(opacity)
                    .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 1, z: 0))
                    .onAppear {
                        // 卡片弹出动画
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0)) {
                            scale = 1.0
                            opacity = 1.0
                            rotation = 0
                        }
                    }
                }
                .transition(.opacity)
                .onDisappear {
                    // 重置状态
                    scale = 0.1
                    opacity = 0
                    rotation = -10
                }
            }
        }
    }
}

// MARK: - Emitter Implementation

private struct ConfettiEmitterView: UIViewRepresentable {
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        
        let emitter = CAEmitterLayer()
        emitter.emitterPosition = CGPoint(x: UIScreen.main.bounds.width / 2, y: -50)
        emitter.emitterShape = .line
        emitter.emitterSize = CGSize(width: UIScreen.main.bounds.width, height: 1)
        emitter.beginTime = CACurrentMediaTime()
        
        var cells: [CAEmitterCell] = []
        
        let colors: [UIColor] = [
            UIColor(red: 0.95, green: 0.40, blue: 0.40, alpha: 1), // Red
            UIColor(red: 0.30, green: 0.85, blue: 0.90, alpha: 1), // Cyan
            UIColor(red: 1.00, green: 0.85, blue: 0.30, alpha: 1), // Yellow
            UIColor(red: 0.40, green: 0.90, blue: 0.50, alpha: 1), // Green
            UIColor(red: 0.70, green: 0.40, blue: 0.90, alpha: 1), // Purple
            UIColor(red: 1.00, green: 0.60, blue: 0.20, alpha: 1)  // Orange
        ]
        
        let shapes: [ConfettiShape] = [.rectangle, .circle, .triangle]
        
        for color in colors {
            for shape in shapes {
                let cell = CAEmitterCell()
                
                cell.birthRate = 12.0
                cell.lifetime = 10.0
                cell.velocity = CGFloat.random(in: 150...300)
                cell.velocityRange = 100
                cell.yAcceleration = 180
                cell.xAcceleration = CGFloat.random(in: -20...20)
                
                cell.emissionLongitude = .pi
                cell.emissionRange = .pi / 4
                cell.spin = 3.5
                cell.spinRange = 4.0
                
                cell.scale = 0.4
                cell.scaleRange = 0.2
                
                cell.contents = generateConfettiImage(shape: shape, color: color).cgImage
                cells.append(cell)
            }
        }
        
        emitter.emitterCells = cells
        view.layer.addSublayer(emitter)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private enum ConfettiShape {
        case rectangle, circle, triangle
    }

    private func generateConfettiImage(shape: ConfettiShape, color: UIColor) -> UIImage {
        let size = CGSize(width: 14, height: 14)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { ctx in
            color.setFill()
            let path: UIBezierPath
            
            switch shape {
            case .rectangle:
                path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: 10, height: 14), cornerRadius: 2)
            case .circle:
                path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: 12, height: 12)))
            case .triangle:
                path = UIBezierPath()
                path.move(to: CGPoint(x: size.width / 2, y: 0))
                path.addLine(to: CGPoint(x: size.width, y: size.height))
                path.addLine(to: CGPoint(x: 0, y: size.height))
                path.close()
            }
            
            path.fill()
        }
    }
}
