import XCTest
@testable import SwiftMusicDLModels

final class DownloadQueueTests: XCTestCase {

    private func entry(_ url: String) -> QueueEntry {
        QueueEntry(sourceUrl: url, title: url, artist: nil)
    }

    // MARK: - Foundational invariants (T007)

    func testSingleAddStartsImmediately() {
        let q = DownloadQueue()
        q.enqueue(entry("a"))
        XCTAssertEqual(q.entries.count, 1)
        XCTAssertEqual(q.entries[0].state, .active)
        XCTAssertEqual(q.activeCount, 1)
    }

    func testSecondItemStaysPending() {
        let q = DownloadQueue()
        q.enqueue(entry("a"))
        q.enqueue(entry("b"))
        XCTAssertEqual(q.entries[0].state, .active)
        XCTAssertEqual(q.entries[1].state, .pending)
        XCTAssertEqual(q.activeCount, 1)
    }

    func testMaxConcurrentCap() {
        let q = DownloadQueue(maxConcurrent: 2)
        q.enqueue(entry("a"))
        q.enqueue(entry("b"))
        q.enqueue(entry("c"))
        XCTAssertEqual(q.activeCount, 2)
        XCTAssertEqual(q.entries.filter { $0.state == .pending }.count, 1)
    }

    func testAutoAdvanceOnComplete() {
        let q = DownloadQueue()
        q.enqueue(entry("a"))
        q.enqueue(entry("b"))
        q.complete("a", downloaded: 1, failed: 0)
        XCTAssertEqual(q.entries[0].state, .done)
        XCTAssertEqual(q.entries[1].state, .active)
    }

    func testCompleteWithFailureSetsFailedAndAdvances() {
        let q = DownloadQueue()
        q.enqueue(entry("a"))
        q.enqueue(entry("b"))
        q.complete("a", downloaded: 0, failed: 1)
        XCTAssertEqual(q.entries[0].state, .failed("1 track(s) failed"))
        XCTAssertEqual(q.entries[1].state, .active)
    }

    func testDuplicateRejected() {
        let q = DownloadQueue()
        q.enqueue(entry("a"))
        XCTAssertFalse(q.enqueue(entry("a")))
        XCTAssertEqual(q.entries.count, 1)
    }

    func testCapacityEnforced() {
        let q = DownloadQueue(capacity: 1)
        XCTAssertTrue(q.enqueue(entry("a")))
        XCTAssertFalse(q.enqueue(entry("b")))
        XCTAssertEqual(q.entries.count, 1)
    }

    // MARK: - Failure handling (US3 / T023)

    func testRetryFailedReEntersQueue() {
        let q = DownloadQueue()
        q.enqueue(entry("a"))
        q.complete("a", downloaded: 0, failed: 1)
        XCTAssertEqual(q.entries[0].state, .failed("1 track(s) failed"))
        q.retry("a")
        XCTAssertEqual(q.entries[0].state, .active)
    }

    func testRemoveFailedEntry() {
        let q = DownloadQueue()
        q.enqueue(entry("a"))
        q.complete("a", downloaded: 0, failed: 1)
        XCTAssertTrue(q.remove("a"))
        XCTAssertEqual(q.entries.count, 0)
    }

    func testCannotRemoveActiveEntry() {
        let q = DownloadQueue()
        q.enqueue(entry("a"))
        XCTAssertFalse(q.remove("a"))
        XCTAssertEqual(q.entries.count, 1)
    }

    func testPauseThenRetryRedownloadsFromScratch() {
        let q = DownloadQueue()
        q.enqueue(entry("a"))
        q.updateTrackStates("a", states: [
            TrackDownloadState(title: "x", artist: nil, status: .downloading),
            TrackDownloadState(title: "y", artist: nil, status: .completed)
        ])
        q.pause("a")
        XCTAssertEqual(q.entries[0].state, .paused)
        q.retry("a")
        XCTAssertEqual(q.entries[0].state, .active)
        XCTAssertEqual(q.entries[0].downloadedCount, 0)
        XCTAssertEqual(q.entries[0].exportedTrackStates[0].status, .pending)
        XCTAssertEqual(q.entries[0].exportedTrackStates[1].status, .pending)
    }

    // MARK: - Output directory (US4 / T029)

    func testDefaultOutputDirectoryIsHomeMusic() {
        let q = DownloadQueue()
        XCTAssertEqual(q.outputDirectory, NSHomeDirectory() + "/Music")
    }

    func testEnqueueBindsCurrentOutputDirectory() {
        let q = DownloadQueue(outputDirectory: "/tmp/out")
        q.enqueue(entry("a"))
        XCTAssertEqual(q.entries[0].outputDirectory, "/tmp/out")
    }

    // MARK: - US1 / US2 flow tests (T011, T018)

    func testEnqueueWhileActiveKeepsSecondPendingAndAutoAdvances() {
        let q = DownloadQueue()
        q.enqueue(entry("a"))
        XCTAssertEqual(q.entries[0].state, .active)
        q.enqueue(entry("b"))
        // Second item pending, first still active, not interrupted.
        XCTAssertEqual(q.entries[0].state, .active)
        XCTAssertEqual(q.entries[1].state, .pending)
        // Auto-advance on completion.
        q.complete("a", downloaded: 1, failed: 0)
        XCTAssertEqual(q.entries[0].state, .done)
        XCTAssertEqual(q.entries[1].state, .active)
    }

    func testEnqueueDoesNotStartDownloadByItselfWhenNotOnlyItem() {
        // Enqueuing a second item must NOT promote it to active on its own (FR-013);
        // it stays pending until the running one completes or a slot frees.
        let q = DownloadQueue()
        q.enqueue(entry("a"))
        let ok = q.enqueue(entry("b"))
        XCTAssertTrue(ok)
        XCTAssertEqual(q.entries.filter { $0.state == .active }.count, 1)
        XCTAssertEqual(q.entries[1].state, .pending)
    }
}