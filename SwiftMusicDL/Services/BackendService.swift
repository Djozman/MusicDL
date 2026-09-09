//
//  BackendService.swift
//  SwiftMusicDL
//

import Foundation
import SwiftMusicDLModels

/// A parsed JSON line emitted by the Python backend while it runs.
public struct BackendEvent {
    public let raw: [String: Any]
    public let type: String
    public let name: String
    public let payload: [String: Any]?

    public init?(line: String) {
        guard let data = line.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let type = obj["type"] as? String else { return nil }
        self.raw = obj
        self.type = type
        self.name = obj["name"] as? String ?? ""
        if let payload = obj["payload"] as? [String: Any] {
            self.payload = payload
        } else {
            self.payload = nil
        }
    }
}

/// Handle to a running download subprocess; `cancel()` terminates it.
public final class DownloadHandle: @unchecked Sendable {
    private let lock = NSLock()
    private var task: Process?
    private(set) public var isCancelled = false

    fileprivate func setTask(_ t: Process) {
        lock.lock(); task = t; lock.unlock()
        if isCancelled { cancel() }
    }

    public func cancel() {
        lock.lock()
        isCancelled = true
        let t = task
        lock.unlock()
        if t?.isRunning == true { t?.terminate() }
    }
}

public class BackendService {
    public static let shared = BackendService()

    /// Absolute path to the Python `antra` backend repository.
    /// When built as a `.app`, set this in the environment or bundle config.
    private let repoPath: String
    private let pythonPath: String

    public init(repoPath: String = "/Users/amm/MusicDL",
                pythonPath: String = "/Library/Frameworks/Python.framework/Versions/3.14/bin/python3") {
        self.repoPath = repoPath
        self.pythonPath = pythonPath
    }

    /// Build a Python `Process` configured to run in the backend repo with
    /// `PYTHONPATH` set and output directed to `~/Music`.
    private func makeProcess(_ args: [String], outputDir: String?, stdout: AnyObject) throws -> Process {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: pythonPath)
        task.arguments = args
        task.currentDirectoryURL = URL(fileURLWithPath: repoPath)

        var env = ProcessInfo.processInfo.environment
        env["PYTHONPATH"] = repoPath
        if let outputDir { env["OUTPUT_DIR"] = outputDir }

        let errPipe = Pipe()
        task.standardOutput = stdout
        task.standardError = errPipe
        task.environment = env
        return task
    }

    /// Run a python script and return (exit status, stdout, stderr).
    private func runPython(_ args: [String], overrideBaseEnv: [String: String]? = nil) throws -> (Int32, String, String) {
        let task = try makeProcess(args, outputDir: NSHomeDirectory() + "/Music", stdout: Pipe())
        var env = task.environment ?? ProcessInfo.processInfo.environment
        if let overrides = overrideBaseEnv {
            for (k, v) in overrides { env[k] = v }
        }
        task.environment = env

        let outPipe = task.standardOutput as! Pipe
        try task.run()
        task.waitUntilExit()

        let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: (task.standardError as! Pipe).fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return (task.terminationStatus, out, err)
    }

    public func searchTracks(_ query: String) async throws -> [SearchResult] {
        let (status, out, err) = try runPython(["search.py", query])
        guard status == 0 else {
            throw NSError(domain: "BackendService", code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: err.isEmpty ? "Search failed" : err])
        }
        let lines = out.split(separator: "\n").map(String.init)
        guard let last = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
              let data = last.data(using: .utf8),
              let payload = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              payload["type"] as? String == "search_results",
              let rawResults = payload["results"] as? [[String: Any]] else {
            throw NSError(domain: "BackendService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Unexpected search response: \(err)"])
        }
        let resultsData = try JSONSerialization.data(withJSONObject: rawResults)
        return try JSONDecoder().decode([SearchResult].self, from: resultsData)
    }

    public func inspectLink(_ urlString: String) async throws -> TrackMetadata {
        let (status, out, err) = try runPython(["preview.py", urlString])
        guard status == 0 else {
            throw NSError(domain: "BackendService", code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: err.isEmpty ? "Preview failed" : err])
        }
        // Parse the last non-empty JSON line as the preview payload.
        let lines = out.split(separator: "\n").map(String.init)
        guard let last = lines.last(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }),
              let data = last.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = payload["type"] as? String, type == "preview" else {
            throw NSError(domain: "BackendService", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Unexpected preview response: \(err)"])
        }
        let decoder = JSONDecoder()
        let json = try JSONSerialization.data(withJSONObject: payload)
        return try decoder.decode(TrackMetadata.self, from: json)
    }

    /// Streaming download for a single track or a selected subset of an
    /// album/playlist. Runs the backend `download.py` helper and invokes
    /// `onEvent` for each parsed JSON line in real time. The optional `--out`
    /// override honors the session's chosen output directory (not just `~/Music`).
    /// Pass a `DownloadHandle` to support cancellation via `SIGTERM`.
    public func downloadSelectedTracks(
        _ urlString: String,
        selectedIndices: [Int],
        outputDir: String = NSHomeDirectory() + "/Music",
        handle: DownloadHandle? = nil,
        onEvent: @escaping (BackendEvent) -> Void
    ) async throws -> Int32 {
        let idx = selectedIndices.map(String.init)
        var args = ["download.py", urlString] + idx
        if !outputDir.isEmpty {
            args.append(contentsOf: ["--out", outputDir])
        }

        return try await runDownloadProcess(args, outputDir: outputDir, handle: handle, onEvent: onEvent)
    }

    /// Low-level download runner: spawns `download.py` and streams parsed JSON-line
    /// events. Shared by the async download APIs and the queue coordinator, so the
    /// queue can start subprocesses per active entry.
    private func runDownloadProcess(
        _ args: [String],
        outputDir: String?,
        handle: DownloadHandle? = nil,
        onEvent: @escaping (BackendEvent) -> Void
    ) async throws -> Int32 {
        // Run on a background thread, reading stdout line-by-line.
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let pipe = Pipe()
                    let task = try self.makeProcess(args, outputDir: outputDir, stdout: pipe)
                    handle?.setTask(task)
                    try task.run()

                    let handle = pipe.fileHandleForReading
                    handle.readabilityHandler = { h in
                        let data = h.availableData
                        guard !data.isEmpty else { return }
                        guard let text = String(data: data, encoding: .utf8) else { return }
                        for line in text.split(separator: "\n") {
                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !trimmed.isEmpty else { continue }
                            if let event = BackendEvent(line: trimmed) {
                                DispatchQueue.main.async {
                                    onEvent(event)
                                }
                            }
                        }
                    }

                    task.waitUntilExit()
                    handle.readabilityHandler = nil
                    let code = task.terminationStatus
                    DispatchQueue.main.async {
                        continuation.resume(returning: code)
                    }
                } catch {
                    DispatchQueue.main.async {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }

    public func downloadTrack(_ urlString: String, outputDir: String = NSHomeDirectory() + "/Music") async throws -> String {
        let (status, out, _) = try runPython(
            ["-m", "antra.json_cli", urlString],
            overrideBaseEnv: ["OUTPUT_DIR": outputDir]
        )
        guard status == 0 else {
            throw NSError(domain: "BackendService", code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "Download failed (exit \(status))"])
        }
        // Best-effort: detect a playlist_summary line.
        var downloaded = 0
        for line in out.split(separator: "\n") {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  obj["type"] as? String == "playlist_summary" else { continue }
            downloaded = obj["downloaded"] as? Int ?? 0
        }
        return downloaded > 0 ? outputDir : "\(outputDir) (completed)"
    }
}