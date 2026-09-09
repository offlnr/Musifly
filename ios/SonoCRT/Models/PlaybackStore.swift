import SwiftUI
import Combine
import AVFoundation
import MediaPlayer
import UIKit

@MainActor
final class PlaybackStore: ObservableObject {
    @Published private(set) var track = MockLibrary.track
    @Published private(set) var isPlaying = false
    @Published private(set) var progress = 0.44
    @Published private(set) var duration: Double = MockLibrary.track.duration
    @Published private(set) var tracks = DemoCatalog.tracks
    @Published private(set) var connected = false
    @Published private(set) var isLoading = false
    @Published private(set) var isBuffering = false
    @Published private(set) var audioOutputName = "IPHONE"
    @Published var errorMessage: String?
    @Published var loop = false
    @Published var shuffle = false
    @Published var showingPlayer = false
    @Published private(set) var loadingMetadata = false
    private var metadataTask: Task<Void, Never>?
    private let nowPlaying = NowPlayingController()
    private var audioNotifications: [NSObjectProtocol] = []
    private var resumeAfterInterruption = false
    private var connection: R2Connection?
    private let player = AVPlayer()
    @Published private(set) var spectrum = AudioSpectrum()
    private var observer: Any?
    private var itemObservation: NSKeyValueObservation?
    private var stateObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var playTask: Task<Void, Never>?
    private var loadTask: Task<Void, Never>?
    private var selectionID = UUID()
    private var libraryID = UUID()
    var queue: [Track] { tracks }
    var elapsed: Double { progress * duration }
    var albums: [Album] {
        guard connected else { return MockLibrary.albums }
        return Dictionary(grouping: tracks, by: \.albumID).map { id, tracks in
            let first = tracks[0]
            return Album(id: id, title: first.albumTitle ?? "Sin álbum", genre: first.genre ?? "", trackCount: tracks.count,
                         artworkData: tracks.compactMap(\.artworkData).first, artist: first.albumArtist ?? first.artist)
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }
    var logs: [LogEntry] {
        connected ? [LogEntry(id: "r2", time: "R2", message: "\(tracks.count) canciones en la biblioteca")] : MockLibrary.logs
    }
    func tracks(in album: Album) -> [Track] { connected ? tracks.filter { $0.albumID == album.id }.sorted { ($0.trackNumber ?? Int.max, $0.title) < ($1.trackNumber ?? Int.max, $1.title) } : DemoCatalog.tracks(in: album) }
    init() {
        nowPlaying.action = { [weak self] action in
            guard let self else { return }
            switch action {
            case .play: self.resume()
            case .pause: self.pause()
            case .toggle: self.toggle()
            case .next: self.next()
            case .previous: self.previous()
            case .seek(let seconds): if self.duration > 0 { self.seek(to: seconds / self.duration) }
            }
        }
        observeAudioSession()
        updateAudioOutput()
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.updateTime() }
        }
        stateObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, self.track.objectKey != nil else { return }
                self.isBuffering = self.player.timeControlStatus == .waitingToPlayAtSpecifiedRate
                self.isPlaying = self.player.timeControlStatus != .paused
                self.updateNowPlaying()
            }
        }
        if let saved = R2Credentials.load() {
            try? R2Credentials.save(saved)
            connection = saved; connected = true; tracks = []; track = Self.emptyTrack; progress = 0; duration = 0
        }
    }
    private static let emptyTrack = Track(id: "empty", title: "Sin canción", artist: "Biblioteca R2", duration: 0)
    func restore() { if connected && tracks.isEmpty { reload() } }
    func connect(endpoint: String, token: String) {
        let address = endpoint.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: address), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/", !secret.isEmpty else { errorMessage = R2Error.invalidConnection.localizedDescription; return }
        let candidate = R2Connection(endpoint: url, token: secret)
        load(candidate, save: true)
    }
    func reload() { if let connection { load(connection, save: false) } }
    private func load(_ candidate: R2Connection, save: Bool) {
        metadataTask?.cancel(); loadingMetadata = false
        loadTask?.cancel(); let generation = UUID(); libraryID = generation
        isLoading = true; errorMessage = nil
        loadTask = Task { [weak self] in
            do {
                let values = try await R2Service(connection: candidate).catalog()
                try Task.checkCancellation()
                guard let self, self.libraryID == generation else { return }
                if save { try R2Credentials.save(candidate) }
                self.stopPlayback()
                self.connection = candidate; self.connected = true; self.tracks = values
                self.track = values.first ?? Self.emptyTrack; self.progress = 0; self.duration = 0
                self.isLoading = false
                self.loadMetadata(for: values, service: R2Service(connection: candidate), generation: generation)
                #if DEBUG
                if ProcessInfo.processInfo.environment["SONO_R2_VERIFY"] == "1" { self.verifyDeviceConnection() }
                #endif
            } catch {
                guard let self, self.libraryID == generation, !Task.isCancelled else { return }
                self.isLoading = false
                self.errorMessage = (error as? R2Error)?.localizedDescription ?? "No se pudo cargar la biblioteca. Revisa tu conexión."
            }
        }
    }
    func disconnect() {
        do { try R2Credentials.remove() } catch { errorMessage = error.localizedDescription; return }
        metadataTask?.cancel(); loadingMetadata = false
        loadTask?.cancel(); libraryID = UUID(); isLoading = false
        stopPlayback(); connection = nil; connected = false; tracks = DemoCatalog.tracks
        track = MockLibrary.track; duration = track.duration; progress = 0.44
    }
    private func stopPlayback() {
        playTask?.cancel(); selectionID = UUID(); itemObservation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }; endObserver = nil
        player.pause(); player.replaceCurrentItem(with: nil); isPlaying = false; isBuffering = false
        spectrum = AudioSpectrum()
        nowPlaying.clear()
    }
    func play(_ value: Track) {
        stopPlayback(); track = tracks.first(where: { $0.id == value.id }) ?? value; progress = 0; duration = track.duration; errorMessage = nil
        guard let key = value.objectKey else {
            if !connected { isPlaying = true }; return
        }
        guard let connection else { return }
        let generation = selectionID
        isBuffering = true; isPlaying = true
        playTask = Task { [weak self] in
            do {
                let url = try await R2Service(connection: connection).playbackURL(for: key)
                try Task.checkCancellation()
                guard let self, self.selectionID == generation else { return }
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                let item = AVPlayerItem(url: url)
                self.itemObservation = item.observe(\.status, options: [.initial, .new]) { [weak self] _, _ in
                    Task { @MainActor [weak self] in
                        guard let self, self.selectionID == generation else { return }
                        if let current = self.player.currentItem, current.status == .readyToPlay, current.audioMix == nil {
                            await self.spectrum.attach(to: current)
                        }
                        if self.player.currentItem?.status == .failed {
                            self.player.pause(); self.isPlaying = false; self.isBuffering = false
                            self.errorMessage = "No se pudo reproducir esta canción. Reintenta o selecciona otra."
                        }
                    }
                }
                self.endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self, self.selectionID == generation else { return }
                        if self.loop { self.restart() } else { self.next() }
                    }
                }
                self.player.replaceCurrentItem(with: item); self.player.play(); self.updateNowPlaying()
            } catch {
                guard let self, self.selectionID == generation, !Task.isCancelled else { return }
                self.isBuffering = false; self.isPlaying = false
                self.errorMessage = (error as? R2Error)?.localizedDescription ?? "No se pudo iniciar la reproducción. Reintenta."
            }
        }
    }
    func pause() {
        resumeAfterInterruption = false
        if player.currentItem == nil { playTask?.cancel(); selectionID = UUID() }
        player.pause(); isPlaying = false; isBuffering = false; updateNowPlaying()
    }
    func resume() {
        guard !tracks.isEmpty else { return }
        if track.objectKey == nil { if !connected { isPlaying = true }; return }
        if player.currentItem == nil || player.currentItem?.status == .failed { play(track); return }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            player.play(); updateNowPlaying()
        } catch { errorMessage = "No se pudo activar la salida de audio." }
    }
    func toggle() { if isPlaying { pause() } else { resume() } }
    func next() {
        guard !queue.isEmpty else { return }
        let index = queue.firstIndex(where: { $0.id == track.id }) ?? 0
        let value = shuffle ? (queue.filter { $0.id != track.id }.randomElement() ?? track) : queue[(index + 1) % queue.count]
        play(value)
    }
    func previous() {
        if elapsed > 3 { seek(to: 0); return }
        guard !queue.isEmpty else { return }
        let index = queue.firstIndex(where: { $0.id == track.id }) ?? 0
        play(queue[(index + queue.count - 1) % queue.count])
    }
    func skip(seconds: Double) { guard duration > 0 else { return }; seek(to: (elapsed + seconds) / duration) }
    func seek(to value: Double) {
        guard duration > 0 else { return }
        progress = min(1, max(0, value))
        if track.objectKey != nil { player.seek(to: CMTime(seconds: elapsed, preferredTimescale: 600)) }; updateNowPlaying()
    }
    private func updateTime() {
        guard track.objectKey != nil, let item = player.currentItem else { return }
        let total = item.duration.seconds; let position = player.currentTime().seconds
        if total.isFinite && total > 0 { duration = total }
        if duration > 0 && position.isFinite { progress = min(1, max(0, position / duration)) }
        updateNowPlaying()
    }
    func tick() {
        guard track.objectKey == nil, !connected, isPlaying else { return }
        progress = min(1, progress + 1 / track.duration)
        if progress >= 1 { if loop { progress = 0 } else { next() } }
    }
    func restart() { if track.objectKey != nil { play(track) } else { progress = 0; isPlaying = true } }
    private func updateNowPlaying() {
        guard track.objectKey != nil, player.currentItem != nil else { return }
        nowPlaying.update(track: track, duration: duration, elapsed: elapsed, rate: player.rate)
    }
    private func loadMetadata(for values: [Track], service: R2Service, generation: UUID) {
        loadingMetadata = true
        metadataTask = Task { [weak self] in
            // Sequential header requests keep initial R2 traffic bounded.
            for value in values {
                guard !Task.isCancelled else { return }
                if let tags = try? await AudioMetadataReader.read(track: value, service: service) {
                    guard let self, !Task.isCancelled, self.libraryID == generation,
                          let index = self.tracks.firstIndex(where: { $0.id == value.id }) else { return }
                    var updated = value
                    if let title = tags.title, !title.isEmpty { updated.title = title }
                    if let artist = tags.artist, !artist.isEmpty { updated.artist = artist }
                    updated.albumTitle = tags.album; updated.albumArtist = tags.albumArtist
                    updated.genre = tags.genre; updated.trackNumber = tags.trackNumber
                    updated.artworkData = tags.artwork
                    if let duration = tags.duration, duration.isFinite, duration > 0 { updated.duration = duration }
                    self.tracks[index] = updated
                    if self.track.id == updated.id { self.track = updated; if updated.duration > 0 { self.duration = updated.duration }; self.updateNowPlaying() }
                }
            }
            guard let self, self.libraryID == generation, !Task.isCancelled else { return }
            self.loadingMetadata = false
            #if DEBUG
            self.writeMetadataVerification()
            #endif
        }
    }
    private func updateAudioOutput() {
        let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
        guard let output = outputs.first else { audioOutputName = "IPHONE"; return }
        switch output.portType {
        case .builtInSpeaker, .builtInReceiver:
            audioOutputName = "IPHONE"
        default:
            audioOutputName = output.portName.localizedCaseInsensitiveContains("airpods") ? "AIRPODS" : output.portName.uppercased()
        }
    }
    private func observeAudioSession() {
        let center = NotificationCenter.default
        #if DEBUG
        audioNotifications.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.verifyBackgroundPlayback() }
        })
        #endif
        audioNotifications.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor [weak self] in
                guard let self else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue {
                    let wasPlaying = self.isPlaying; self.pause(); self.resumeAfterInterruption = wasPlaying
                } else if type == AVAudioSession.InterruptionType.ended.rawValue {
                    let shouldResume = self.resumeAfterInterruption && AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume)
                    self.resumeAfterInterruption = false
                    if shouldResume { self.resume() }
                }
            }
        })
        audioNotifications.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateAudioOutput()
                if reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { self.pause() }
            }
        })
        audioNotifications.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }; self.stopPlayback()
                self.errorMessage = "La salida de audio se reinició. Pulsa reproducir para continuar."
            }
        })
    }
    #if DEBUG
    private func verifyBackgroundPlayback() {
        guard ProcessInfo.processInfo.environment["SONO_BACKGROUND_VERIFY"] == "1", isPlaying else { return }
        let initial = player.currentTime().seconds
        let generation = selectionID
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard let self, self.selectionID == generation else { return }
            let info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            let result: [String: Any] = ["background": UIApplication.shared.applicationState == .background,
                "advancedSeconds": self.player.currentTime().seconds - initial,
                "playing": self.player.timeControlStatus == .playing,
                "lockScreenTitle": info[MPMediaItemPropertyTitle] as? String ?? "",
                "lockScreenArtist": info[MPMediaItemPropertyArtist] as? String ?? "",
                "lockScreenArtwork": info[MPMediaItemPropertyArtwork] != nil,
                "timestamp": Date().timeIntervalSince1970]
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
                try? data.write(to: directory.appendingPathComponent("background-verification.json"), options: .atomic)
            }
        }
    }
    private func writeMetadataVerification() {
        guard ProcessInfo.processInfo.environment["SONO_METADATA_VERIFY"] == "1" else { return }
        let records = tracks.map { ["title": $0.title, "artist": $0.artist, "album": $0.albumTitle ?? "", "artworkBytes": $0.artworkData?.count ?? 0, "duration": $0.duration] as [String: Any] }
        let result: [String: Any] = ["tracks": records, "albumCount": albums.count, "timestamp": Date().timeIntervalSince1970]
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) { try? data.write(to: directory.appendingPathComponent("metadata-verification.json"), options: .atomic) }
    }
    #endif
    #if DEBUG
    /// Explicitly enabled only during local device verification; never exports credentials.
    private func verifyDeviceConnection() {
        guard let first = tracks.first else { return }
        player.volume = 0
        play(first)
        let generation = selectionID
        Task { [weak self] in
            guard let self else { return }
            var decoded = false
            var spectrumPeak: Float = 0
            for _ in 0..<40 {
                try? await Task.sleep(for: .milliseconds(500))
                if self.selectionID != generation { break }
                if self.player.timeControlStatus == .playing && self.player.currentTime().seconds > 0 {
                    decoded = true
                    spectrumPeak = max(spectrumPeak, self.spectrum.snapshot().max() ?? 0)
                    if spectrumPeak > 0 { break }
                }
                if self.errorMessage != nil { break }
            }
            if self.selectionID == generation {
                self.player.pause(); self.isPlaying = false; self.isBuffering = false
                self.seek(to: 0)
            }
            self.player.volume = 1
            let result: [String: Any] = ["connected": self.connected, "trackCount": self.tracks.count,
                "keychainSaved": R2Credentials.load() != nil, "audioDecoded": decoded, "spectrumPeak": spectrumPeak,
                "duration": self.duration, "timestamp": Date().timeIntervalSince1970]
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: .prettyPrinted) {
                try? data.write(to: directory.appendingPathComponent("r2-verification.json"), options: .atomic)
            }
        }
    }
    #endif
    deinit {
        loadTask?.cancel(); playTask?.cancel(); metadataTask?.cancel()
        for observer in audioNotifications { NotificationCenter.default.removeObserver(observer) }
        if let observer { player.removeTimeObserver(observer) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }
}
