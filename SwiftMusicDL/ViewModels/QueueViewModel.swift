//
//  QueueViewModel.swift
//  SwiftMusicDL
//

import Foundation
import Combine
import SwiftMusicDLModels

@MainActor
public class QueueViewModel: ObservableObject {
    @Published public private(set) var queue: DownloadQueue

    private let backend = BackendService.shared
    private var runningIDs: Set<String> = []
    private var runningHandles: [String: DownloadHandle] = [:]
    private var cancellables: Set<AnyCancellable> = []

    public init(queue: DownloadQueue = DownloadQueue()) {
        self.queue = queue
        queue.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    public var outputDirectory: String {
        get { queue.outputDirectory }
        set { queue.outputDirectory = newValue }
    }

    @discardableResult
    public func enqueue(_ entry: QueueEntry, allowDuplicate: Bool = false) -> Bool {
        guard queue.enqueue(entry, allowDuplicate: allowDuplicate) else { return false }
        driveActiveEntries()
        return true
    }

    public func contains(_ url: String) -> Bool { queue.contains(url) }

    public func retry(_ id: String) {
        queue.retry(id)
        driveActiveEntries()
    }

    public func remove(_ id: String) {
        cancel(id)
        let _ = queue.remove(id)
        driveActiveEntries()
    }

    public func cancel(_ id: String) {
        runningHandles[id]?.cancel()
    }

    public func pauseAll() {
        let activeIDs = queue.entries.filter { $0.state == .active }.map { $0.sourceUrl }
        for id in activeIDs { queue.pause(id) }
    }

    private func driveActiveEntries() {
        for entry in queue.entries where entry.state == .active && !runningIDs.contains(entry.sourceUrl) {
            startDownload(for: entry)
        }
    }

    private func startDownload(for entry: QueueEntry) {
        let id = entry.sourceUrl
        runningIDs.insert(id)
        let handle = DownloadHandle()
        runningHandles[id] = handle

        Task {
            let code: Int32
            do {
                code = try await backend.downloadSelectedTracks(
                    entry.sourceUrl,
                    selectedIndices: entry.selectedIndices,
                    outputDir: entry.outputDirectory,
                    handle: handle
                ) { [weak self] event in
                    self?.handleBackendEvent(event, for: id)
                }
            } catch {
                code = 1
            }
            runningIDs.remove(id)
            runningHandles[id] = nil
            if handle.isCancelled {
                queue.pause(id)
                driveActiveEntries()
            } else {
                self.finish(entryID: id, exitCode: code)
            }
        }
    }

    private func handleBackendEvent(_ event: BackendEvent, for id: String) {
        guard let idx = queue.entries.firstIndex(where: { $0.sourceUrl == id }) else { return }

        switch event.type {
        case "event":
            updateTrackState(event, for: idx)
        case "download_summary":
            let downloaded = event.raw["downloaded"] as? Int ?? 0
            queue.setDownloadedCount(id, to: downloaded)
        default:
            break
        }
    }

    private func updateTrackState(_ event: BackendEvent, for idx: Int) {
        let name = event.payload?["track"] as? String ?? ""
        var states = queue.entries[idx].exportedTrackStates
        if states.isEmpty {
            let total = queue.entries[idx].totalTracks
            states = (0..<max(total, 1)).map { _ in TrackDownloadState(title: nil, artist: nil, status: .pending) }
        }

        // Track which event fired and update count for completions
        if event.name == "track_completed" || event.name == "track_skipped" {
            queue.incrementDownloadedCount(queue.entries[idx].sourceUrl)
        }

        // Update per-track state if we can match
        if !name.isEmpty {
            if let si = states.firstIndex(where: { $0.title == name }) {
                switch event.name {
                case "track_started": states[si].status = .downloading
                case "track_completed", "track_skipped": states[si].status = .completed
                case "track_failed": states[si].status = .failed(event.payload?["error"] as? String ?? "Failed")
                default: break
                }
            } else if let si = states.firstIndex(where: { $0.status == .pending }) {
                // Assign to first pending slot if name doesn't match
                states[si].title = name
                states[si].artist = event.payload?["artist"] as? String
                switch event.name {
                case "track_started": states[si].status = .downloading
                case "track_completed", "track_skipped": states[si].status = .completed
                case "track_failed": states[si].status = .failed(event.payload?["error"] as? String ?? "Failed")
                default: break
                }
            }
        }
        queue.updateTrackStates(queue.entries[idx].sourceUrl, states: states)
    }

    private func finish(entryID id: String, exitCode: Int32) {
        runningIDs.remove(id)
        guard let idx = queue.entries.firstIndex(where: { $0.sourceUrl == id }) else { return }
        let entry = queue.entries[idx]
        let hadFailures = exitCode != 0
        queue.complete(id, downloaded: entry.downloadedCount, failed: hadFailures ? 1 : 0)
        driveActiveEntries()
    }
}
