//
//  MainViewModel.swift
//  SwiftMusicDL
//

import Foundation
import Combine
import SwiftMusicDLModels

@MainActor
public class MainViewModel: ObservableObject {
    @Published public var inputURL: String = ""
    @Published public var status: DownloadStatus = .idle
    @Published public var statusMessage: String = ""
    @Published public var currentPreview: TrackMetadata?
    private let backend = BackendService.shared
    private var currentContentType: ContentType = .single
    private var downloadedCount = 0

    public init() {}

    public func submitURL() {
        guard !inputURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        status = .fetching
        statusMessage = "Fetching track metadata..."
        let urlToFetch = inputURL
        Task {
            do {
                let metadata = try await backend.inspectLink(urlToFetch)
                self.currentPreview = metadata
                self.currentContentType = metadata.contentType
                if metadata.contentType != .single && !metadata.selectableTracks.isEmpty {
                    self.status = .selectingTracks(metadata.selectableTracks)
                    self.statusMessage = "Select tracks to download."
                } else {
                    self.status = .previewReady(metadata)
                    self.statusMessage = "Preview ready."
                }
            } catch {
                self.status = .error(error.localizedDescription)
                self.statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }

    public func confirmDownload() {
        guard case .previewReady = status else { return }
        startDownload(selectedIndices: [0])
    }

    public func updateSelection(tracks: [SelectableTrack]) {
        if case .selectingTracks = status { status = .selectingTracks(tracks) }
    }

    public func confirmSelection() {
        guard case .selectingTracks(let tracks) = status else { return }
        let selectedIndices = tracks.enumerated().filter { $0.element.selected }.map { $0.offset }
        guard !selectedIndices.isEmpty else { statusMessage = "Select at least one track to download."; return }
        startDownload(selectedIndices: selectedIndices)
    }

    private func startDownload(selectedIndices: [Int]) {
        let urlToDownload = inputURL
        let isMulti = currentContentType != .single || selectedIndices.count > 1
        let total = selectedIndices.count
        let initialStates: [TrackDownloadState]
        if isMulti {
            let names = payloadTrackNames()
            initialStates = selectedIndices.map { selIdx in
                let name = (selIdx >= 0 && selIdx < names.count) ? names[selIdx] : nil
                return TrackDownloadState(title: name, artist: nil, status: .pending)
            }
        } else { initialStates = [] }
        status = .downloading(initialStates)
        downloadedCount = 0
        statusMessage = downloadingText(current: 1, total: total, trackName: nil)
        Task {
            do {
                let code = try await backend.downloadSelectedTracks(urlToDownload, selectedIndices: selectedIndices) { [weak self] event in self?.handleBackendEvent(event) }
                if code != 0 { self.statusMessage = "Download finished with exit code \(code)." }
            } catch {
                self.status = .error(error.localizedDescription)
                self.statusMessage = "Download failed: \(error.localizedDescription)"
            }
        }
    }

    private func payloadTrackNames() -> [String] {
        switch status {
        case .selectingTracks(let tracks): return tracks.map { $0.title ?? "" }
        case .previewReady(let metadata): return metadata.selectableTracks.map { $0.title ?? metadata.title }
        default: return []
        }
    }

    public func makeQueueEntry(outputDirectory: String = NSHomeDirectory() + "/Music") -> QueueEntry? {
        guard let metadata = currentPreview else { return nil }
        let indices: [Int]
        let title: String
        switch status {
        case .selectingTracks(let tracks):
            indices = tracks.enumerated().filter { $0.element.selected }.map { $0.offset }
            title = metadata.title
            if indices.isEmpty { return nil }
        case .previewReady:
            indices = [0]
            title = metadata.title
        default: return nil
        }
        let total = max(indices.count, 1)
        var entry = QueueEntry(sourceUrl: inputURL, title: title, artist: metadata.artist, artworkURL: metadata.artworkURL, contentType: metadata.contentType, selectedIndices: indices, totalTracks: metadata.contentType == .single ? 1 : total, outputDirectory: outputDirectory)
        if metadata.contentType == .single {
            entry.exportedTrackStates = [TrackDownloadState(title: metadata.title, artist: metadata.artist, status: .pending)]
        } else {
            let selectable = metadata.selectableTracks
            entry.exportedTrackStates = indices.compactMap { idx in
                guard idx >= 0 && idx < selectable.count else { return nil }
                let t = selectable[idx]
                return TrackDownloadState(title: t.title, artist: t.artist, status: .pending)
            }
        }
        return entry
    }

    public func downloadingText(current: Int = 1, total: Int = 1, trackName: String?) -> String {
        let folder = NSHomeDirectory() + "/Music"
        if currentContentType == .single || total <= 1 { return "Downloading track \(trackName ?? "…") to \(folder)" }
        return "Downloading track \(current)/\(total) (\(trackName ?? "…")) to \(folder)"
    }

    private func handleBackendEvent(_ event: BackendEvent) {
        switch event.type {
        case "event": handleEngineEvent(event)
        case "progress": break
        case "download_summary":
            if let downloaded = event.raw["downloaded"] as? Int {
                let failed = event.raw["failed"] as? Int ?? 0
                let message = failed > 0 ? "Download finished. \(downloaded) downloaded, \(failed) failed." : "Download complete. \(downloaded) track\(downloaded == 1 ? "" : "s") downloaded."
                statusMessage = message
                if case .downloading = status { status = .completed(message) }
            }
        default: break
        }
    }

    private func handleEngineEvent(_ event: BackendEvent) {
        guard var states: [TrackDownloadState] = currentTrackStates(), !states.isEmpty else { return }
        let name = event.payload?["track"] as? String ?? ""
        if let idx = states.firstIndex(where: { $0.title == name || ($0.title == nil && $0.artist == nil) }) {
            switch event.name {
            case "track_started": states[idx].status = .downloading
            case "track_completed": states[idx].status = .completed
            case "track_skipped": states[idx].status = .completed
            case "track_failed": states[idx].status = .failed(event.payload?["error"] as? String ?? "Failed")
            default: break
            }
        }
        status = .downloading(states)
        let total = states.count
        let current = states.firstIndex(where: { $0.status == .downloading || $0.status == .completed }).map { $0 + 1 } ?? 0
        downloadedCount = states.filter { $0.status == .completed }.count
        statusMessage = downloadingText(current: current > 0 ? current : 1, total: total, trackName: name)
        if states.allSatisfy({ $0.status == .completed || stateIsFailure($0.status) }) {
            let failures = states.filter { stateIsFailure($0.status) }.count
            let message: String
            if failures == 0 { message = "Download complete." }
            else if failures == states.count { message = "Download failed (\(failures) track\(failures == 1 ? "" : "s"))." }
            else { message = "Download finished with \(failures) failure(s)." }
            statusMessage = message
            status = .completed(message)
        }
    }

    private func stateIsFailure(_ state: TrackProgressState) -> Bool { if case .failed = state { return true }; return false }
    private func currentTrackStates() -> [TrackDownloadState]? { if case .downloading(let states) = status { return states }; return nil }

    public func reset() {
        inputURL = ""
        status = .idle
        statusMessage = ""
        currentPreview = nil
        currentContentType = .single
        downloadedCount = 0
    }
}
