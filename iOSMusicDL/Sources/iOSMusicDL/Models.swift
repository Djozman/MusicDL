import Foundation

struct Preview: Codable {
    let type: String?
    let title: String?
    let artist: String?
    let album: String?
    let artworkURL: String?
    let source: String?
    let trackCount: Int?
    let tracks: [PreviewTrack]?
    enum CodingKeys: String, CodingKey {
        case type, title, artist, album, source
        case artworkURL = "artwork_url"
        case trackCount = "track_count"
        case tracks
    }
    struct PreviewTrack: Codable {
        let title: String?
        let artist: String?
        let durationMs: Int?
        enum CodingKeys: String, CodingKey {
            case title, artist
            case durationMs = "duration_ms"
        }
    }
}

struct TrackProgress: Codable {
    let title: String?
    let artist: String?
    let index: Int?
    let total: Int?
    let status: String?
}

struct DownloadSummary: Codable {
    let type: String?
    let exit: Int?
    let session: String?
    let status: String?
    let files: [String]?
    let base_url: String?
    let message: String?
    let track_progress: [TrackProgress]?
    let completed_tracks: Int?
}
