import Foundation

struct Track: Identifiable {
    let id: String
    var title: String
    var artist: String
    var duration: Double
    var objectKey: String? = nil
    var metadataVersion: String? = nil
    var albumTitle: String? = nil
    var albumArtist: String? = nil
    var genre: String? = nil
    var trackNumber: Int? = nil
    var artworkData: Data? = nil
    var albumID: String { (albumArtist ?? artist) + "::" + (albumTitle ?? "Sin álbum") }
}
struct Album: Identifiable {
    let id: String
    var title: String
    let genre: String
    let trackCount: Int
    var artworkData: Data? = nil
    var artist: String? = nil
}
struct LogEntry: Identifiable {
    let id: String
    let time: String
    let message: String
}
enum MockLibrary {
    static let track = Track(id: "signal", title: "Canción 1", artist: "Artista 1", duration: 284)
    static let albums = [
        Album(id: "noise", title: "Álbum 1", genre: "ambient", trackCount: 42),
        Album(id: "grid", title: "Álbum 2", genre: "dub", trackCount: 28),
        Album(id: "slow", title: "Álbum 3", genre: "slowcore", trackCount: 16),
        Album(id: "jazz", title: "Álbum 4", genre: "jazz", trackCount: 55)
    ]
    static let logs = [
        LogEntry(id: "added", time: "14:02", message: "añadido Canción 6"),
        LogEntry(id: "synced", time: "11:47", message: "canal Álbum 1 sincronizado")
    ]
}
