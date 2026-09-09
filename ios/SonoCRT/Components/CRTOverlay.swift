import SwiftUI

/// Static scanlines and a dithered vignette: no gradient or animation.
struct CRTOverlay: View {
    @Environment(\.displayScale) private var scale
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        Canvas { context, size in
            guard !reduceTransparency else { return }
            let pixel = 1 / scale
            for y in stride(from: CGFloat.zero, to: size.height, by: 3) {
                context.fill(Path(CGRect(x: 0, y: y, width: size.width, height: pixel)), with: .color(.black.opacity(0.06)))
            }
            for y in stride(from: CGFloat.zero, to: size.height, by: 4) {
                for x in stride(from: CGFloat.zero, to: size.width, by: 4) {
                    let dx = (x - size.width / 2) / (size.width / 2)
                    let dy = (y - size.height / 2) / (size.height / 2)
                    let edge = max(0, (dx * dx + dy * dy - 0.55) / 1.45)
                    if edge > 0 {
                        context.fill(Path(CGRect(x: x, y: y, width: 3, height: 3)), with: .color(.black.opacity(edge * 0.38)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
