//
//  TrackMetadata.swift
//  SwiftMusicDL
//

import Foundation

public struct TrackMetadata: Codable, Identifiable, Equatable {
    public var id: String { artworkURL ?? title }
    public let title: String
    public let artist: String
    public let album: String
    public let artworkURL: String?
    public let source: String?
    public let trackCount: Int?
    /// True = explicit, false = clean/edited, nil = unknown. Passed through from the
    /// backend preview payload. Defaults to nil so older payloads decode as "unknown".
    public let isExplicit: Bool?
    /// For playlists/albums, the list of individual tracks (title + artist + duration).
    public let tracks: [TrackPreview]?

    /// Convenience: resolve whether this is a single track or a multi-track album/playlist.
    public var contentType: ContentType {
        let count = trackCount ?? tracks?.count ?? 0
        return count > 1 ? .album : .single
    }

    /// Derives the explicit/clean/unknown status for display.
    public var explicitStatus: ExplicitStatus { ExplicitStatus(isExplicit: isExplicit) }

    /// Convenience: convert preview tracks to selectable items for the checklist.
    public var selectableTracks: [SelectableTrack] {
        (tracks ?? []).map {
            SelectableTrack(title: $0.title, artist: $0.artist, durationMS: $0.durationMS)
        }
    }

    enum CodingKeys: String, CodingKey {
        case title
        case artist
        case album
        case artworkURL = "artwork_url"
        case source
        case trackCount = "track_count"
        case isExplicit = "is_explicit"
        case tracks
    }
}

public struct TrackPreview: Codable, Identifiable, Equatable {
    public var id: String { "\(artist)-\(title)-\(durationMS)" }
    public let artist: String?
    public let title: String?
    public let durationMS: Int?

    enum CodingKeys: String, CodingKey {
        case artist
        case title
        case durationMS = "duration_ms"
    }
}

public struct DownloadRequest: Codable {
    public let url: String
    public let source: String?
}