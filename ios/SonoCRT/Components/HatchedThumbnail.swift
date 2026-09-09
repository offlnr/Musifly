import SwiftUI

struct HatchedThumbnail: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: -size.height, through: size.width, by: 7) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
            }
            context.stroke(path, with: .color(CRTTheme.ink.opacity(0.55)), lineWidth: 1)
        }
        .background(CRTTheme.panel).clipped().crtBorder(0.8).accessibilityHidden(true)
    }
}
