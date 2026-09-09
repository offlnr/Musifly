import SwiftUI

struct PlaylistsView: View {
    @ObservedObject var playback: PlaybackStore
    @EnvironmentObject private var playlists: PlaylistStore
    @State private var showingCreate = false
    @State private var filter = "CANALES"
    private func filterButton(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(CRTTheme.mono(11)).lineLimit(1).minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(active ? CRTTheme.highlight : CRTTheme.ink)
                .crtBorder(active ? 1 : 0.55)
        }.buttonStyle(.plain)
    }
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                TerminalHeader(title: "DISCO LOCAL", subtitle: playback.connected ? "// \(playback.tracks.count) canciones · biblioteca privada" : "// biblioteca de demostración · 62% usado")
                TerminalSection(title: "MIS PLAYLISTS")
                ForEach(playlists.playlists) { playlist in
                    NavigationLink { PlaylistDetailView(playlistID: playlist.id) } label: {
                        HStack {
                            Text(playlist.name)
                            Spacer()
                            Text("\(playlist.trackIDs.count) pistas")
                        }.font(CRTTheme.mono(13)).frame(minHeight: 48)
                    }.buttonStyle(.plain)
                }
                TerminalSection(title: "BIBLIOTECA")
                if !playback.connected { SegmentedProgress(progress: 0.62) }
                HStack(spacing: 8) {
                    ForEach(["CANALES", "PISTAS", "NODOS"], id: \.self) { item in
                        filterButton(item, active: filter == item) { filter = item }
                    }
                    filterButton("+ NUEVA", active: false) { showingCreate = true }
                        .accessibilityLabel("Nueva playlist")
                }
                if filter == "CANALES" {
                    ForEach(playback.albums) { album in
                        NavigationLink { AlbumDetailView(album: album) } label: {
                            HStack {
                                Text("DIR").opacity(0.6)
                                Text("/" + album.title).foregroundStyle(CRTTheme.highlight)
                                Spacer(); Text("\(album.trackCount)")
                            }.font(CRTTheme.mono(12)).frame(minHeight: 44)
                        }.buttonStyle(.plain)
                    }
                } else if filter == "PISTAS" {
                    ForEach(playback.tracks) { TrackRow(track: $0, playback: playback) }
                } else {
                    ForEach(Array(Set(playback.tracks.map(\.artist))).sorted(), id: \.self) { artist in
                        VStack(alignment: .leading) {
                            TerminalSection(title: "/" + artist)
                            ForEach(playback.tracks.filter { $0.artist == artist }) { TrackRow(track: $0, playback: playback) }
                        }
                    }
                }
            }.padding(24)
        }
        .sheet(isPresented: $showingCreate) {
            PlaylistEditorView().environmentObject(playlists)
                .presentationDragIndicator(.visible).presentationCornerRadius(0)
        }
    }
}
