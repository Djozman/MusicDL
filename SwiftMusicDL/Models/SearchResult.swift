//
//  SearchResult.swift
//  SwiftMusicDL
//

import Foundation

/// Explicit/clean status of a track, derived from the provider's flag.
public enum ExplicitStatus: String, Codable {
    case explicit
    case clean
    case unknown

    public init(isExplicit: Bool?) {
        switch isExplicit {
        case .some(true): self = .explicit
        case .some(false): self = .clean
        case .none: self = .unknown
        }
    }

    /// Human-readable label for the indicator chip.
    public var label: String {
        switch self {
        case .explicit: return "Explicit"
        case .clean: return "Clean"
        case .unknown: return "Unknown"
        }
    }
}

public struct SearchResult: Codable, Identifiable {
    public var id: String { trackURL ?? "\(artist ?? "")-\(title ?? "")" }
    public let type: String?
    public let title: String?
    public let artist: String?
    public let album: String?
    public let subtitle: String?
    public let artworkURL: String?
    public let trackURL: String?
    public let source: String?
    /// True = explicit, false = clean/edited, nil = unknown (FR-005).
    public let isExplicit: Bool?

    /// Derives the explicit/clean/unknown status for display.
    public var explicitStatus: ExplicitStatus { ExplicitStatus(isExplicit: isExplicit) }

    enum CodingKeys: String, CodingKey {
        case type
        case title
        case artist
        case album
        case subtitle
        case artworkURL = "artwork_url"
        case trackURL = "track_url"
        case source
        case isExplicit = "is_explicit"
    }

    /// "album" vs "track"/"single".
    public var isAlbum: Bool { type == "album" }
}