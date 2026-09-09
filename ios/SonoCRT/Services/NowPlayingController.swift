import Foundation
import MediaPlayer
import UIKit

@MainActor
final class NowPlayingController {
    enum Action { case play, pause, toggle, next, previous, seek(Double) }
    var action: ((Action) -> Void)?
    private var handlers: [(MPRemoteCommand, Any)] = []
    private var artworkData: Data?
    private var artwork: MPMediaItemArtwork?
    init() {
        let center = MPRemoteCommandCenter.shared()
        register(center.playCommand, .play)
        register(center.pauseCommand, .pause)
        register(center.togglePlayPauseCommand, .toggle)
        register(center.nextTrackCommand, .next)
        register(center.previousTrackCommand, .previous)
        let target = center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor [weak self] in self?.action?(.seek(position)) }
            return .success
        }
        handlers.append((center.changePlaybackPositionCommand, target))
        setEnabled(false)
    }
    private func register(_ command: MPRemoteCommand, _ value: Action) {
        let target = command.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.action?(value) }
            return .success
        }
        handlers.append((command, target))
    }
    private func setEnabled(_ enabled: Bool) { for (command, _) in handlers { command.isEnabled = enabled } }
    func update(track: Track, duration: Double, elapsed: Double, rate: Float) {
        setEnabled(true)
        if artworkData != track.artworkData {
            artworkData = track.artworkData
            if let data = track.artworkData, let image = UIImage(data: data) {
                artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            } else { artwork = nil }
        }
        var info: [String: Any] = [MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed,
            MPNowPlayingInfoPropertyPlaybackRate: rate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue]
        if duration > 0 { info[MPMediaItemPropertyPlaybackDuration] = duration }
        if let title = track.albumTitle { info[MPMediaItemPropertyAlbumTitle] = title }
        if let artwork { info[MPMediaItemPropertyArtwork] = artwork }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPRemoteCommandCenter.shared().changePlaybackPositionCommand.isEnabled = duration > 0
    }
    func clear() { MPNowPlayingInfoCenter.default().nowPlayingInfo = nil; setEnabled(false) }
    deinit { for (command, target) in handlers { command.removeTarget(target) } }
}
