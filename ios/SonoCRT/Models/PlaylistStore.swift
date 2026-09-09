import Foundation
import Combine

struct UserPlaylist: Identifiable, Codable {
    let id: UUID
    var name: String
    var trackIDs: [String]
}

@MainActor
final class PlaylistStore: ObservableObject {
    @Published private(set) var playlists: [UserPlaylist]
    private let defaults: UserDefaults
    private let key = "sono.playlists.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        playlists = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([UserPlaylist].self, from: $0) } ?? []
    }

    @discardableResult
    func create(name: String, trackID: String? = nil) -> UUID? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        let playlist = UserPlaylist(id: UUID(), name: clean, trackIDs: trackID.map { [$0] } ?? [])
        playlists.append(playlist)
        save()
        return playlist.id
    }

    func add(trackID: String, to id: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == id }),
              !playlists[index].trackIDs.contains(trackID) else { return }
        playlists[index].trackIDs.append(trackID)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(playlists) { defaults.set(data, forKey: key) }
    }
}
