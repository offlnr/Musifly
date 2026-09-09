import SwiftUI

struct PlaybackSeekBar: View {
    @ObservedObject var playback: PlaybackStore
    @GestureState private var draggedProgress: Double?
    private var value: Double { draggedProgress ?? playback.progress }
    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    SegmentedProgress(progress: value)
                    Rectangle().fill(CRTTheme.highlight)
                        .frame(width: 6, height: 18)
                        .offset(x: max(0, geometry.size.width - 6) * value)
                }
                .frame(height: 44)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .updating($draggedProgress) { drag, state, _ in
                        guard playback.duration > 0 else { return }
                        state = min(1, max(0, drag.location.x / max(1, geometry.size.width)))
                    }
                    .onEnded { drag in
                        guard playback.duration > 0 else { return }
                        playback.seek(to: min(1, max(0, drag.location.x / max(1, geometry.size.width))))
                    })
            }.frame(height: 44)
            HStack {
                Text(DemoCatalog.time(value * playback.duration))
                Spacer()
                Text(DemoCatalog.time(playback.duration))
            }.font(CRTTheme.mono(11))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Posición de reproducción")
        .accessibilityValue(DemoCatalog.time(value * playback.duration) + " de " + DemoCatalog.time(playback.duration))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: playback.skip(seconds: 10)
            case .decrement: playback.skip(seconds: -10)
            @unknown default: break
            }
        }
    }
}
