import SwiftUI

struct AlbumCard: View {
    let album: Album
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AlbumArtwork(data: album.artworkData).aspectRatio(1, contentMode: .fit)
            Text(album.title).lineLimit(2, reservesSpace: true).font(CRTTheme.title(17)).foregroundStyle(CRTTheme.highlight)
            Text(album.artist ?? " ").font(CRTTheme.mono(10)).lineLimit(2, reservesSpace: true).opacity(0.75)
            Text(album.genre.isEmpty ? "\(album.trackCount) pistas" : "\(album.genre) / \(album.trackCount) pistas").font(CRTTheme.mono(10)).lineLimit(1).opacity(0.75)
        }.frame(maxWidth: .infinity, minHeight: 102, alignment: .leading)
            .padding(12).background(CRTTheme.panel).crtBorder()
    }
}
