//
//  SearchViewModel.swift
//  SwiftMusicDL
//

import Foundation
import Combine
import SwiftMusicDLModels

@MainActor
public class SearchViewModel: ObservableObject {
    @Published public var query: String = ""
    @Published public var results: [SearchResult] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    private let backend = BackendService.shared
    private var searchTask: Task<Void, Never>?

    public init() {}

    /// Called when the user submits a search query.
    public func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        searchTask?.cancel()

        isLoading = true
        errorMessage = nil
        results = []

        let q = trimmed
        searchTask = Task {
            do {
                let found = try await backend.searchTracks(q)
                guard !Task.isCancelled else { return }
                self.results = found
                if found.isEmpty {
                    self.errorMessage = "No results found."
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    /// Returns the result's resolvable track URL, for feeding the download flow.
    public func selectedResultURL(_ result: SearchResult) -> String? {
        guard let url = result.trackURL, !url.isEmpty else { return nil }
        return url
    }
}