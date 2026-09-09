import SwiftUI

struct PlaylistDetailView: View {
    let playlistID: UUID
    @EnvironmentObject private var playlists: PlaylistStore
    @EnvironmentObject private var playback: PlaybackStore
    private var playlist: UserPlaylist? { playlists.playlists.first { $0.id == playlistID } }
    private var tracks: [Track] {
        (playlist?.trackIDs ?? []).compactMap { id in playback.tracks.first { $0.id == id } }
    }
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                TerminalHeader(title: playlist?.name ?? "PLAYLIST", subtitle: "// \(tracks.count) canciones disponibles")
                if tracks.isEmpty {
                    Text("Mantén presionada una canción y elige Agregar a playlist.")
                        .font(CRTTheme.mono(13))
                }
                ForEach(tracks) { TrackRow(track: $0, playback: playback) }
            }.padding(24)
        }.background(CRTTheme.background)
        .gestureBackNavigation()
    }
}
