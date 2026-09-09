import SwiftUI

struct SegmentedProgress: View {
    var progress: Double
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let count = max(1, Int(geometry.size.width / 5))
                for index in 0..<count {
                    let active = Double(index) / Double(count) < progress
                    context.fill(Path(CGRect(x: CGFloat(index) * 5 + 2, y: 2, width: 2, height: size.height - 4)), with: .color(CRTTheme.ink.opacity(active ? 1 : 0.12)))
                }
            }
        }.frame(height: 8).crtBorder()
        .accessibilityLabel("Progreso").accessibilityValue("\(Int(progress * 100)) por ciento")
    }
}
