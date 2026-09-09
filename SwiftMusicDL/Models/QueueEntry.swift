//
//  QueueEntry.swift
//  SwiftMusicDL
//

import Foundation

public enum QueueState: Equatable {
    case pending
    case active
    case done
    case failed(String)
    case paused
}

extension QueueState {
    public var isTerminal: Bool {
        switch self {
        case .done, .failed: return true
        case .pending, .active, .paused: return false
        }
    }
}

public struct QueueEntry: Identifiable, Equatable {
    public var id: String { sourceUrl }
    public let sourceUrl: String
    public var title: String
    public var artist: String?
    public var artworkURL: String?
    public var contentType: ContentType
    public var selectedIndices: [Int]
    public var totalTracks: Int
    public var downloadedCount: Int
    public var exportedTrackStates: [TrackDownloadState]
    public var state: QueueState
    public var outputDirectory: String

    public init(
        sourceUrl: String,
        title: String,
        artist: String?,
        artworkURL: String? = nil,
        contentType: ContentType = .single,
        selectedIndices: [Int] = [],
        totalTracks: Int = 1,
        outputDirectory: String = NSHomeDirectory() + "/Music"
    ) {
        self.sourceUrl = sourceUrl
        self.title = title
        self.artist = artist
        self.artworkURL = artworkURL
        self.contentType = contentType
        self.selectedIndices = selectedIndices
        self.totalTracks = totalTracks
        self.downloadedCount = 0
        self.exportedTrackStates = []
        self.state = .pending
        self.outputDirectory = outputDirectory
    }
}
