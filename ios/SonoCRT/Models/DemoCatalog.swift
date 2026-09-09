import Foundation

enum DemoCatalog {
    static let tracks = [MockLibrary.track,
        Track(id: "static", title: "Canción 2", artist: "Artista 1", duration: 304),
        Track(id: "blue", title: "Canción 3", artist: "Artista 2", duration: 202),
        Track(id: "end", title: "Canción 4", artist: "Artista 3", duration: 287),
        Track(id: "radio", title: "Canción 5", artist: "Artista 4", duration: 138),
        Track(id: "echo", title: "Canción 6", artist: "Artista 1", duration: 256)]
    static func tracks(in album: Album) -> [Track] {
        let index = MockLibrary.albums.firstIndex(where: { $0.id == album.id }) ?? 0
        return Array(tracks.dropFirst(index).prefix(3))
    }
    static func time(_ seconds: Double) -> String {
        let value = max(0, Int(seconds))
        return String(format: "%02d:%02d", value / 60, value % 60)
    }
}
