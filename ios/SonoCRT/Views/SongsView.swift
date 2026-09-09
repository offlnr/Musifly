import SwiftUI

struct SongsView: View {
    @ObservedObject var playback: PlaybackStore
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                TerminalHeader(title: "CANCIONES", subtitle: "// \(playback.tracks.count) pistas disponibles")
                NavigationLink { SystemView() } label: {
                    HStack { Text("SYS/NODO_07"); Spacer(); Text("AJUSTES >") }.font(CRTTheme.mono(12)).padding(14).crtBorder()
                }.buttonStyle(.plain)
                if playback.isLoading { Text("CARGANDO BIBLIOTECA…").font(CRTTheme.mono()) }
                if playback.connected && !playback.isLoading && playback.tracks.isEmpty {
                    Text("No se encontraron archivos de audio compatibles.").font(CRTTheme.mono())
                }
                ForEach(playback.tracks) { TrackRow(track: $0, playback: playback) }
            }.padding(24)
        }
    }
}
