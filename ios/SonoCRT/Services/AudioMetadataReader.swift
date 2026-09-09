import Foundation
import AVFoundation
import CryptoKit
import ImageIO
import UIKit

struct AudioTags: Codable {
    var title: String?
    var artist: String?
    var album: String?
    var albumArtist: String?
    var genre: String?
    var trackNumber: Int?
    var duration: Double?
    var artwork: Data?
}

/// Reads headers, not entire FLAC files. Other containers use AVFoundation metadata.
enum AudioMetadataReader {
    static func read(track: Track, service: R2Service) async throws -> AudioTags {
        let identity = service.connection.endpoint.absoluteString + "|" + track.id + "|" + (track.metadataVersion ?? "")
        let digest = SHA256.hash(data: Data(identity.utf8)).map { String(format: "%02x", $0) }.joined()
        let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("AudioMetadata")
        let cache = directory.appendingPathComponent(digest + ".json")
        if track.metadataVersion != nil, let data = try? Data(contentsOf: cache), let tags = try? JSONDecoder().decode(AudioTags.self, from: data) { return tags }
        let url = try await service.playbackURL(for: track.objectKey ?? track.id)
        var tags: AudioTags
        if (track.objectKey ?? "").lowercased().hasSuffix(".flac") { tags = try await readFLAC(url: url) }
        else { tags = try await readAsset(url: url) }
        if let artwork = tags.artwork { tags.artwork = thumbnail(artwork) }
        try Task.checkCancellation()
        if track.metadataVersion != nil {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if let data = try? JSONEncoder().encode(tags) { try? data.write(to: cache, options: .atomic) }
        }
        return tags
    }
    private static func thumbnail(_ data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 768
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.85)
    }
    private static func readAsset(url: URL) async throws -> AudioTags {
        let asset = AVURLAsset(url: url)
        let items = try await asset.load(.commonMetadata)
        func text(_ id: AVMetadataIdentifier) async -> String? {
            guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: id).first else { return nil }
            return try? await item.load(.stringValue)
        }
        var result = AudioTags()
        result.title = await text(.commonIdentifierTitle)
        result.artist = await text(.commonIdentifierArtist)
        result.album = await text(.commonIdentifierAlbumName)
        if let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierArtwork).first {
            result.artwork = try? await item.load(.dataValue)
        }
        if let duration = try? await asset.load(.duration), duration.seconds.isFinite { result.duration = duration.seconds }
        return result
    }
    private static func readFLAC(url: URL) async throws -> AudioTags {
        let session = URLSession(configuration: .ephemeral)
        defer { session.finishTasksAndInvalidate() }
        var buffer = Data()
        func ensure(_ count: Int) async throws {
            guard count <= 32 * 1024 * 1024 else { throw R2Error.invalidCatalog }
            if buffer.count >= count { return }
            let offset = buffer.count
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            request.setValue("bytes=\(offset)-\(max(count, offset + 65536) - 1)", forHTTPHeaderField: "Range")
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse, response.statusCode == 206,
                  response.value(forHTTPHeaderField: "Content-Range")?.hasPrefix("bytes \(offset)-") == true,
                  data.count <= 32 * 1024 * 1024 else { throw R2Error.unavailable }
            buffer.append(data)
            guard buffer.count >= count else { throw R2Error.invalidCatalog }
        }
        try await ensure(4)
        guard buffer.prefix(4) == Data("fLaC".utf8) else { return try await readAsset(url: url) }
        var result = AudioTags(), offset = 4
        for _ in 0..<128 {
            try Task.checkCancellation()
            try await ensure(offset + 4)
            let header = buffer[offset], type = header & 0x7f
            let length = Int(buffer[offset+1]) << 16 | Int(buffer[offset+2]) << 8 | Int(buffer[offset+3])
            offset += 4
            try await ensure(offset + length)
            let bytes = Data(buffer[offset..<offset+length])
            if type == 0, bytes.count == 34 {
                let packed = bytes[10..<18].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
                let sampleRate = packed >> 44, samples = packed & 0xFFFFFFFFF
                if sampleRate > 0 { result.duration = Double(samples) / Double(sampleRate) }
            } else if type == 4 {
                var reader = TagBytes(data: bytes)
                _ = try reader.take(try reader.integer(little: true))
                let count = try reader.integer(little: true)
                guard count <= 10000 else { throw R2Error.invalidCatalog }
                var fields: [String: [String]] = [:]
                for _ in 0..<count {
                    let data = try reader.take(try reader.integer(little: true))
                    if let text = String(data: data, encoding: .utf8), let equal = text.firstIndex(of: "=") {
                        let key = text[..<equal].uppercased()
                        let value = text[text.index(after: equal)...].trimmingCharacters(in: .whitespacesAndNewlines)
                        if !value.isEmpty { fields[key, default: []].append(value) }
                    }
                }
                result.title = fields["TITLE"]?.first
                result.artist = fields["ARTIST"]?.joined(separator: ", ")
                result.album = fields["ALBUM"]?.first
                result.albumArtist = fields["ALBUMARTIST"]?.first ?? fields["ALBUM ARTIST"]?.first
                result.genre = fields["GENRE"]?.first
                result.trackNumber = fields["TRACKNUMBER"]?.first?.split(separator: "/").first.flatMap { Int($0) }
            } else if type == 6 {
                var reader = TagBytes(data: bytes)
                let pictureType = try reader.integer()
                let mime = try reader.take(try reader.integer())
                _ = try reader.take(try reader.integer())
                _ = try reader.take(16)
                let image = try reader.take(try reader.integer())
                // Linked pictures are not fetched; prefer the embedded front cover.
                if String(data: mime, encoding: .utf8) != "-->", result.artwork == nil || pictureType == 3 { result.artwork = image }
            }
            offset += length
            if header & 0x80 != 0 { return result }
        }
        throw R2Error.invalidCatalog
    }
}

private struct TagBytes {
    let data: Data
    private var offset = 0
    init(data: Data) { self.data = data }
    mutating func take(_ count: Int) throws -> Data {
        guard count >= 0, count <= data.count - offset else { throw R2Error.invalidCatalog }
        defer { offset += count }
        return Data(data[offset..<offset+count])
    }
    mutating func integer(little: Bool = false) throws -> Int {
        let bytes = try take(4)
        return (little ? Array(bytes.reversed()) : Array(bytes)).reduce(0) { ($0 << 8) | Int($1) }
    }
}
