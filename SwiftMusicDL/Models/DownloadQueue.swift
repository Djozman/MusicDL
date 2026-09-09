//
//  DownloadQueue.swift
//  SwiftMusicDL
//

import Foundation

/// The per-session, ordered download queue with a concurrency/slot model.
///
/// Invariants:
/// - At most `maxConcurrent` entries are `active` at once.
/// - Promotion to `active` happens only when a slot frees and the entry is the FIFO
///   head among pending/retry candidates.
/// - Enqueuing never starts a download by itself unless the queue was empty (the
///   sole entry becomes active).
/// - A failed entry does not block others.
/// - Re-download always restarts from scratch (no partial resume).
public final class DownloadQueue: ObservableObject {
    @Published public private(set) var entries: [QueueEntry] = []
    @Published public var outputDirectory: String

    public let maxConcurrent: Int
    public let capacity: Int

    public private(set) var sessionId: String = UUID().uuidString

    public init(
        outputDirectory: String = NSHomeDirectory() + "/Music",
        maxConcurrent: Int = 1,
        capacity: Int = 100
    ) {
        self.outputDirectory = outputDirectory
        self.maxConcurrent = max(1, maxConcurrent)
        self.capacity = capacity
    }

    /// Number of currently active (downloading) entries.
    public var activeCount: Int { entries.filter { $0.state == .active }.count }

    /// Whether a download slot is free to start a new active entry.
    public var hasFreeSlot: Bool { activeCount < maxConcurrent }

    // MARK: - Enqueue

    /// Adds an entry to the waitlist. If the queue was empty it becomes active
    /// immediately; otherwise it stays pending until a slot frees.
    ///
    /// Returns `false` when the queue is at capacity or the URL is already queued.
    @discardableResult
    public func enqueue(_ entry: QueueEntry, allowDuplicate: Bool = false) -> Bool {
        if capacity > 0 && entries.count >= capacity { return false }
        if !allowDuplicate && entries.contains(where: { $0.sourceUrl == entry.sourceUrl }) { return false }
        var entry = entry
        entry.outputDirectory = outputDirectory
        entry.state = .pending
        entries.append(entry)
        promoteNext()
        return true
    }

    // MARK: - Transition helpers

    /// Marks an entry as finished. `failed` > 0 drives `failed`; otherwise `done`.
    public func complete(_ id: String, downloaded: Int, failed: Int) {
        guard let idx = index(of: id) else { return }
        entries[idx].downloadedCount = downloaded
        entries[idx].state = failed > 0 ? .failed("\(failed) track(s) failed") : .done
        promoteNext()
    }

    /// Marks an in-progress entry as paused (interruption).
    public func pause(_ id: String) {
        guard let idx = index(of: id), entries[idx].state == .active else { return }
        entries[idx].state = .paused
        promoteNext()
    }

    /// Retries a failed/paused entry: re-download from scratch in the next free slot.
    public func retry(_ id: String) {
        guard let idx = index(of: id) else { return }
        let st = entries[idx].state
        guard st == .paused || { if case .failed = st { return true }; return false }() else { return }
        entries[idx].downloadedCount = 0
        entries[idx].exportedTrackStates = entries[idx].exportedTrackStates.map {
            TrackDownloadState(title: $0.title, artist: $0.artist, status: .pending)
        }
        if hasFreeSlot {
            entries[idx].state = .active
        } else {
            entries[idx].state = .pending
        }
    }

    /// Removes an entry from the queue at any state except active.
    @discardableResult
    public func remove(_ id: String) -> Bool {
        guard let idx = index(of: id), entries[idx].state != .active else { return false }
        entries.remove(at: idx)
        return true
    }

    /// Updates the per-track state list of an entry (driven by backend events).
    public func updateTrackStates(_ id: String, states: [TrackDownloadState]) {
        guard let idx = index(of: id) else { return }
        entries[idx].exportedTrackStates = states
    }

    /// Increments the downloaded-track count of an entry (from backend completion events).
    public func incrementDownloadedCount(_ id: String, by delta: Int = 1) {
        guard let idx = index(of: id) else { return }
        entries[idx].downloadedCount += delta
    }

    /// Sets the downloaded-track count of an entry (from a download summary).
    public func setDownloadedCount(_ id: String, to count: Int) {
        guard let idx = index(of: id) else { return }
        entries[idx].downloadedCount = count
    }

    /// Promotes the FIFO pending candidates into free slots.
    private func promoteNext() {
        while hasFreeSlot {
            guard let idx = entries.firstIndex(where: { $0.state == .pending }) else { break }
            entries[idx].state = .active
        }
    }

    private func index(of id: String) -> Int? {
        entries.firstIndex(where: { $0.sourceUrl == id })
    }

    /// True if the queue contains an entry for this URL.
    public func contains(_ url: String) -> Bool {
        entries.contains(where: { $0.sourceUrl == url })
    }
}