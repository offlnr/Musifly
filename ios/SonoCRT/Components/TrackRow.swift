import SwiftUI

struct TrackRow: View {
    let track: Track
    @ObservedObject var playback: PlaybackStore
    var body: some View {
        Button { playback.play(track); playback.showingPlayer = true } label: {
            HStack(spacing: 12) {
                AlbumArtwork(data: track.artworkData).frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 5) {
                    Text(track.title).lineLimit(2).font(CRTTheme.mono(12)).foregroundStyle(playback.track.id == track.id ? CRTTheme.highlight : CRTTheme.ink)
                    Text(track.artist + " · pista").font(CRTTheme.mono(10)).opacity(0.6)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Text(track.duration > 0 ? DemoCatalog.time(track.duration) : "--:--").font(CRTTheme.mono(11)).opacity(0.75)
            }.padding(.vertical, 10).contentShape(Rectangle())
        }.buttonStyle(.plain).playlistMenu(for: track)
    }
}
