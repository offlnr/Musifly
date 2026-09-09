import SwiftUI

struct HomeView: View {
    @ObservedObject var playback: PlaybackStore
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                TerminalHeader()
                if playback.loadingMetadata { Text("LEYENDO ÁLBUMES Y CARÁTULAS…").font(CRTTheme.mono(10)).opacity(0.65) }
                VStack(alignment: .leading, spacing: 12) {
                    sectionTitle("ÁLBUMES RECIENTES")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        ForEach(playback.albums) { album in
                            NavigationLink { AlbumDetailView(album: album) } label: { AlbumCard(album: album) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    sectionTitle("REGISTRO RECIENTE")
                    ForEach(playback.logs) { LogRow(entry: $0) }
                }
            }.padding(.horizontal, CRTTheme.margin).padding(.top, 18).padding(.bottom, 24)
        }.scrollIndicators(.hidden)
    }
    private func sectionTitle(_ text: String) -> some View {
        Text(text).font(CRTTheme.mono(10)).tracking(2).opacity(0.75).accessibilityAddTraits(.isHeader)
    }
}
