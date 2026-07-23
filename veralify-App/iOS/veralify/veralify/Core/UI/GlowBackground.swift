import SwiftUI

/// Soft ambient "mesh glow" background: a few large, heavily blurred color
/// orbs drifting behind a light canvas, built from the Veralify brand
/// palette (#141414, #dcdcdc, #de6c15, #e8ebee). Purely decorative and
/// stateless, so it costs nothing to keep mounted behind scrolling/streaming
/// content.
struct GlowBackground: View {
    var body: some View {
        ZStack {
            AppTheme.canvas

            Circle()
                .fill(AppTheme.accent.opacity(0.32))
                .frame(width: 280, height: 280)
                .blur(radius: 95)
                .offset(x: -140, y: -280)

            Circle()
                .fill(AppTheme.surface.opacity(0.55))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 150, y: -160)

            Circle()
                .fill(AppTheme.accent.opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 90)
                .offset(x: 140, y: 260)

            Circle()
                .fill(AppTheme.ink.opacity(0.10))
                .frame(width: 240, height: 240)
                .blur(radius: 90)
                .offset(x: -150, y: 380)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    GlowBackground()
}
