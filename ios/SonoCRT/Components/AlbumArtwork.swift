import SwiftUI

struct AlbumArtwork: View {
    let data: Data?
    var body: some View {
        GeometryReader { geometry in
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height).clipped()
            } else { HatchedThumbnail() }
        }.crtBorder().accessibilityHidden(true)
    }
}
