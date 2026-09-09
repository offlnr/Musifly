import SwiftUI

struct PlaylistEditorView: View {
    @EnvironmentObject private var playlists: PlaylistStore
    @Environment(\.dismiss) private var dismiss
    var track: Track? = nil
    @State private var name = ""
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                TerminalButton(title: "< VOLVER") { dismiss() }
                TerminalSection(title: track == nil ? "NUEVA PLAYLIST" : "AGREGAR A PLAYLIST")
                if let track {
                    Text(track.title).font(CRTTheme.title(22))
                    ForEach(playlists.playlists) { playlist in
                        let contains = playlist.trackIDs.contains(track.id)
                        Button {
                            playlists.add(trackID: track.id, to: playlist.id)
                            dismiss()
                        } label: {
                            HStack {
                                Text(playlist.name)
                                Spacer()
                                Text(contains ? "AGREGADA" : "+")
                            }.font(CRTTheme.mono(13)).frame(minHeight: 48)
                        }.buttonStyle(.plain).disabled(contains)
                    }
                    TerminalSection(title: "CREAR NUEVA PLAYLIST")
                }
                TextField("Nombre de la playlist", text: $name)
                    .font(CRTTheme.mono(15)).padding(12)
                    .overlay(Rectangle().stroke(CRTTheme.ink, lineWidth: 1 / UIScreen.main.scale))
                    .submitLabel(.done).onSubmit { create() }
                TerminalButton(title: track == nil ? "+ CREAR PLAYLIST" : "+ CREAR Y AGREGAR") { create() }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding(24)
        }
        .background(CRTTheme.background.ignoresSafeArea())
        .foregroundStyle(CRTTheme.ink).tint(CRTTheme.ink).preferredColorScheme(.dark)
    }
    private func create() {
        if playlists.create(name: name, trackID: track?.id) != nil { dismiss() }
    }
}
