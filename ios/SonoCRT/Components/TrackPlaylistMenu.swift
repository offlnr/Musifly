import SwiftUI

struct TrackPlaylistMenu: ViewModifier {
    let track: Track
    @EnvironmentObject private var playlists: PlaylistStore
    @State private var showingPicker = false
    func body(content: Content) -> some View {
        content.contextMenu {
            Button("Agregar a playlist", systemImage: "text.badge.plus") { showingPicker = true }
        }
        .sheet(isPresented: $showingPicker) {
            PlaylistEditorView(track: track).environmentObject(playlists)
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(0)
        }
    }
}

extension View {
    func playlistMenu(for track: Track) -> some View { modifier(TrackPlaylistMenu(track: track)) }
}
