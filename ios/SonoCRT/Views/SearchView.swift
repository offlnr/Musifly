import SwiftUI

struct SearchView: View {
    @ObservedObject var playback: PlaybackStore
    @State private var query = ""
    private var tracks: [Track] { playback.tracks.filter { query.isEmpty || ($0.title + $0.artist + ($0.albumTitle ?? "")).localizedStandardContains(query) } }
    private var albums: [Album] { playback.albums.filter { query.isEmpty || ($0.title + $0.genre + ($0.artist ?? "")).localizedStandardContains(query) } }
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                TerminalHeader(title: "BUSCAR", subtitle: "// consulta la biblioteca local")
                HStack {
                    Text("grep").font(CRTTheme.title(18))
                    TextField("pista, artista o canal", text: $query).font(CRTTheme.mono(13))
                        .textInputAutocapitalization(.never).autocorrectionDisabled().accessibilityLabel("Buscar en la biblioteca")
                    if !query.isEmpty { Button { query = "" } label: { Text("×").frame(width: 44, height: 44) }.accessibilityLabel("Borrar búsqueda") }
                }.padding(.horizontal, 14).frame(minHeight: 52).background(CRTTheme.panel).crtBorder()
                TerminalSection(title: "\(tracks.count + albums.count) RESULTADOS — LOCAL")
                if tracks.isEmpty && albums.isEmpty { Text("// sin coincidencias; prueba otra consulta").font(CRTTheme.mono()) }
                VStack(spacing: 0) {
                    ForEach(tracks) { TrackRow(track: $0, playback: playback) }
                    ForEach(albums) { album in
                        NavigationLink { AlbumDetailView(album: album) } label: {
                            HStack { Text("DIR /" + album.title); Spacer(); Text(">") }.font(CRTTheme.mono(12)).frame(minHeight: 48)
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(24)
        }.scrollDismissesKeyboard(.interactively)
    }
}
