//
//  DownloadState.swift
//  SwiftMusicDL
//

import Foundation

public enum ContentType: String, Codable, Equatable {
    case single
    case album
    case playlist
}

public struct SelectableTrack: Identifiable, Equatable {
    public var id: String { "\(artist ?? "")-\(title ?? "")-\(durationMS ?? 0)" }
    public let title: String?
    public let artist: String?
    public let durationMS: Int?
    public var selected: Bool
    public init(title: String?, artist: String?, durationMS: Int?, selected: Bool = true) {
        self.title = title
        self.artist = artist
        self.durationMS = durationMS
        self.selected = selected
    }
}

public enum TrackProgressState: Equatable {
    case pending
    case downloading
    case completed
    case failed(String)
}

public struct TrackDownloadState: Identifiable, Equatable {
    public var id: String { "\(artist ?? "")-\(title ?? "")" }
    public var title: String?
    public var artist: String?
    public var status: TrackProgressState
    public init(title: String?, artist: String?, status: TrackProgressState = .pending) {
        self.title = title
        self.artist = artist
        self.status = status
    }
}

public enum DownloadStatus: Equatable {
    case idle
    case fetching
    case previewReady(TrackMetadata)
    case selectingTracks([SelectableTrack])
    case downloading([TrackDownloadState])
    case completed(String)
    case error(String)
}
