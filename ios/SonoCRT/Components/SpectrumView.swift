import SwiftUI

struct SpectrumView: View {
    let spectrum: AudioSpectrum
    let isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 / 15 : 1.0 / 60, paused: !isPlaying)) { _ in
            let levels = isPlaying ? spectrum.snapshot() : Array(repeating: Float(0), count: 32)
            Canvas { context, size in
                let gap: CGFloat = 2
                let width = (size.width - gap * CGFloat(levels.count - 1)) / CGFloat(levels.count)
                for (index, level) in levels.enumerated() {
                    let height = max(2, CGFloat(level) * (size.height - 2))
                    let x = CGFloat(index) * (width + gap)
                    let rect = CGRect(x: x, y: size.height - height, width: width, height: height)
                    context.fill(Path(rect), with: .color(CRTTheme.ink.opacity(0.88)))
                    context.fill(Path(CGRect(x: x, y: rect.minY, width: width, height: 2)), with: .color(CRTTheme.highlight))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
