import SwiftUI

struct FantasySkyBackground: View {
    var height: CGFloat = 280

    var body: some View {
        ZStack {
            AppTheme.heroGradient.frame(height: height)
            cloudsLayer
            sparklesLayer
        }
        .frame(height: height)
        .clipped()
    }

    private var cloudsLayer: some View {
        ZStack {
            cloudEllipse(.init(w: 300, h: 80), blur: 30, opacity: 0.7, offset: (-40, height * 0.3))
            cloudEllipse(.init(w: 250, h: 70), blur: 25, opacity: 0.7, offset: (60, height * 0.35))
            cloudEllipse(.init(w: 180, h: 50), blur: 20, opacity: 0.4, offset: (-100, height * 0.1))
            cloudEllipse(.init(w: 200, h: 60), blur: 22, opacity: 0.35, offset: (80, height * 0.05))
            cloudEllipse(.init(w: 160, h: 40), blur: 18, opacity: 0.2, offset: (30, -height * 0.2))

            // 底部フェードで背景色に溶け込む
            LinearGradient(colors: [.clear, AppTheme.background], startPoint: .top, endPoint: .bottom)
                .frame(height: 60)
                .offset(y: height * 0.5 - 30)
        }
    }

    private func cloudEllipse(_ size: CGSize, blur: CGFloat, opacity: Double, offset: (CGFloat, CGFloat)) -> some View {
        Ellipse()
            .fill(Color.white.opacity(opacity))
            .frame(width: size.width, height: size.height)
            .blur(radius: blur)
            .offset(x: offset.0, y: offset.1)
    }

    private var sparklesLayer: some View {
        let items: [(size: CGFloat, opacity: Double, x: CGFloat, y: CGFloat, isAccent: Bool)] = [
            (18, 0.9, -80, -60, false), (14, 0.8, 100, -50, false),
            (10, 0.7, 120, 20, false),  (8, 0.6, -110, 10, false),
            (12, 0.7, -30, -80, false), (6, 0.5, 50, 50, false),
            (22, 0.6, 60, -70, true),   (16, 0.5, -60, -40, true),
        ]
        return ZStack {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Image(systemName: "sparkle")
                    .font(.system(size: item.size, weight: .light))
                    .foregroundStyle(
                        item.isAccent
                            ? AppTheme.accent.opacity(item.opacity)
                            : Color.white.opacity(item.opacity)
                    )
                    .offset(x: item.x, y: item.y)
            }
        }
    }
}

private extension CGSize {
    init(w: CGFloat, h: CGFloat) { self.init(width: w, height: h) }
}
