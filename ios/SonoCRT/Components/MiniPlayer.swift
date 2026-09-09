import SwiftUI

struct MiniPlayer: View {
    @ObservedObject var playback: PlaybackStore
    var expanded = false
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if expanded { Text("CONTINUAR").font(CRTTheme.mono(10)).tracking(2).opacity(0.75) }
            HStack(spacing: 12) {
                AlbumArtwork(data: playback.track.artworkData).frame(width: expanded ? 54 : 38, height: expanded ? 54 : 38)
                Button { playback.showingPlayer = true } label: {
                VStack(alignment: .leading, spacing: 5) {
                    Text(playback.track.title).font(CRTTheme.title(expanded ? 17 : 12)).foregroundStyle(CRTTheme.highlight)
                        .lineLimit(1).minimumScaleFactor(0.7)
                    Text(playback.track.artist + (expanded ? " · \(Int(playback.progress * 100))% completado" : ""))
                        .font(CRTTheme.mono(10)).opacity(0.75)
                }.frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(.plain).accessibilityLabel("Abrir reproductor")
                Button(action: playback.toggle) {
                    Image(systemName: playback.isPlaying ? "pause" : "play")
                        .font(.system(size: 20, weight: .medium)).frame(width: 44, height: 44)
                }.buttonStyle(.plain)
                    .accessibilityLabel(playback.isPlaying ? "Pausar" : "Reproducir")
            }
            if playback.isBuffering { Text("CARGANDO AUDIO…").font(CRTTheme.mono(10)) }
            if expanded { SegmentedProgress(progress: playback.progress) }
        }.padding(14).background(CRTTheme.panel).crtBorder()
    }
}
