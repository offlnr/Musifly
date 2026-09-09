import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    @EnvironmentObject private var playback: PlaybackStore
    private var currentAlbum: Album { playback.albums.first(where: { $0.id == album.id }) ?? album }
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                TerminalHeader(title: album.title, subtitle: "// álbum · " + album.genre)
                AlbumArtwork(data: currentAlbum.artworkData).aspectRatio(1, contentMode: .fit)
                Text("\(album.trackCount) pistas").font(CRTTheme.mono(11))
                ForEach(playback.tracks(in: album)) { TrackRow(track: $0, playback: playback) }
            }.padding(24)
        }.background(CRTTheme.background)
            .gestureBackNavigation()
    }
}
