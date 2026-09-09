//
//  ContentView.swift
//  SwiftMusicDL
//

import SwiftUI
import AppKit
import SwiftMusicDLModels

public struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @StateObject private var searchViewModel = SearchViewModel()
    @StateObject private var queueViewModel = QueueViewModel()
    @State private var selectionTracks: [SelectableTrack] = []
    @State private var duplicateEntry: QueueEntry?
    @State private var alertMessage: String?
    @State private var activeTab: DetailTab = .search
    @State private var selectedQueueID: String?

    public init() {}

    public var body: some View {
        NavigationSplitView {
            QueueSidebar(
                viewModel: queueViewModel,
                selectedID: $selectedQueueID,
                onSelectEntry: { id in
                    selectedQueueID = id
                    activeTab = .album
                }
            )
            .navigationSplitViewColumnWidth(min: 260, ideal: 300, max: 420)
            .navigationTitle("Queue")
        } detail: {
            VStack(spacing: 0) {
                tabPicker
                Divider()
                switch activeTab {
                case .search:
                    searchDetail
                case .album:
                    albumDetail
                }
            }
        }
        .frame(minWidth: 860, minHeight: 560)
        .alert(
            alertMessage ?? "",
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { dismissAlert() } }
            )
        ) {
            if duplicateEntry != nil {
                Button("Re-download") { confirmDuplicate() }
                Button("Cancel", role: .cancel) { dismissAlert() }
            } else {
                Button("OK", role: .cancel) { dismissAlert() }
            }
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(.search, label: "Search", icon: "magnifyingglass")
            tabButton(.album, label: "Album", icon: "music.note.list")
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func tabButton(_ tab: DetailTab, label: String, icon: String) -> some View {
        Button {
            activeTab = tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.system(size: 13, weight: activeTab == tab ? .semibold : .regular))
            .foregroundColor(activeTab == tab ? .accentColor : .secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(activeTab == tab ? Color.accentColor.opacity(0.1) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }

    private var searchDetail: some View {
        VStack(spacing: 0) {
            inputBar.padding()
            Divider()
            searchBody.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("Paste a music link, or search…", text: $viewModel.inputURL)
                .textFieldStyle(.roundedBorder)
                .onSubmit(handlePrimaryInput)
            if !viewModel.inputURL.isEmpty {
                Button { viewModel.inputURL = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            Button("Go", action: handlePrimaryInput).buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder private var searchBody: some View {
        switch viewModel.status {
        case .idle:
            if !searchViewModel.results.isEmpty || searchViewModel.isLoading { searchResults } else { emptyPrompt }
        case .fetching:
            VStack(spacing: 12) {
                ProgressView().controlSize(.large)
                Text(viewModel.statusMessage).foregroundColor(.secondary)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .previewReady(let metadata):
            PreviewCard(metadata: metadata) { enqueueCurrent() } onCancel: { viewModel.reset() }
        case .selectingTracks(let tracks):
            SelectionList(tracks: $selectionTracks, artworkURL: viewModel.currentPreview?.artworkURL, title: viewModel.currentPreview?.title) { enqueueCurrent() } onCancel: { viewModel.reset() }.onAppear { selectionTracks = tracks }
        case .downloading, .completed:
            VStack(spacing: 12) {
                Text(viewModel.statusMessage)
                Button("Done") { viewModel.reset() }.buttonStyle(.borderedProminent)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error:
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundColor(.red)
                Text(viewModel.statusMessage).multilineTextAlignment(.center).foregroundColor(.red)
                Button("Try Again") { viewModel.status = .idle }.buttonStyle(.bordered)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var emptyPrompt: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note").font(.system(size: 44)).foregroundColor(.secondary)
            Text("Paste a link or search for a song").foregroundColor(.secondary)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchResults: some View {
        List {
            if searchViewModel.isLoading {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Searching…").foregroundColor(.secondary) }
            } else if let error = searchViewModel.errorMessage {
                Text(error).foregroundColor(.red)
            } else {
                ForEach(searchViewModel.results) { result in
                    Button { pickSearchResult(result) } label: { SearchResultRow(result: result) }.buttonStyle(.plain)
                }
            }
        }.listStyle(.inset)
    }

    private func pickSearchResult(_ result: SearchResult) {
        guard let url = searchViewModel.selectedResultURL(result) else { return }
        viewModel.inputURL = url
        viewModel.submitURL()
    }

    private func handlePrimaryInput() {
        let text = viewModel.inputURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if text.contains("://") || text.lowercased().hasPrefix("www.") { viewModel.submitURL() }
        else { searchViewModel.query = text; searchViewModel.search() }
    }

    @ViewBuilder private var albumDetail: some View {
        if let id = selectedQueueID, let entry = queueViewModel.queue.entries.first(where: { $0.sourceUrl == id }) {
            AlbumProgressView(entry: entry)
        } else {
            VStack(spacing: 8) {
                Image(systemName: "music.note.list").font(.system(size: 44)).foregroundColor(.secondary)
                Text("Select an album or playlist from the queue to see progress.").foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func enqueueCurrent() {
        viewModel.updateSelection(tracks: selectionTracks)
        if let entry = viewModel.makeQueueEntry(outputDirectory: queueViewModel.outputDirectory) { addToQueue(entry) }
        viewModel.reset()
    }

    private func addToQueue(_ entry: QueueEntry) {
        if queueViewModel.contains(entry.sourceUrl) {
            duplicateEntry = entry
            alertMessage = "\"\(entry.title)\" is already in the queue. Re-download anyway?"
            return
        }
        if !queueViewModel.enqueue(entry) { alertMessage = "The queue is full or the item could not be added." }
    }

    private func confirmDuplicate() {
        if let entry = duplicateEntry { _ = queueViewModel.enqueue(entry, allowDuplicate: true) }
        dismissAlert()
    }

    private func dismissAlert() { duplicateEntry = nil; alertMessage = nil }
}

private enum DetailTab { case search, album }

// MARK: - Album progress view

private struct AlbumProgressView: View {
    let entry: QueueEntry
    private var stateLabel: (String, Color) {
        switch entry.state {
        case .pending: return ("Pending", .secondary)
        case .active: return ("Downloading", .accentColor)
        case .done: return ("Done", .green)
        case .failed: return ("Failed", .red)
        case .paused: return ("Paused", .orange)
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                albumArtwork(entry: entry)
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title).font(.title2).lineLimit(2)
                    if let artist = entry.artist, !artist.isEmpty { Text(artist).font(.subheadline).foregroundColor(.secondary) }
                    let (label, color) = stateLabel
                    Text(label).font(.caption).foregroundColor(color)
                }
                Spacer()
            }.padding()
            Divider()
            if entry.totalTracks > 1 {
                VStack(spacing: 6) {
                    ProgressView(value: Double(entry.downloadedCount), total: Double(entry.totalTracks))
                    Text("\(entry.downloadedCount) of \(entry.totalTracks) tracks").font(.caption).foregroundColor(.secondary)
                }.padding()
            }
            Divider()
            if entry.exportedTrackStates.isEmpty {
                VStack { Spacer(); if entry.state == .active { ProgressView().controlSize(.large); Text("Waiting for track info…").foregroundColor(.secondary).padding(.top, 8) } else { Text("No track data available.").foregroundColor(.secondary) }; Spacer() }
            } else {
                List {
                    ForEach(entry.exportedTrackStates) { track in
                        HStack(spacing: 10) {
                            Image(systemName: trackStatusIcon(track.status)).foregroundColor(trackStatusColor(track.status)).frame(width: 20)
                            Text(track.title ?? "Track").lineLimit(1)
                            Spacer()
                            Text(trackStatusText(track.status)).font(.caption).foregroundColor(trackStatusColor(track.status))
                        }.padding(.vertical, 2)
                    }
                }.listStyle(.inset)
            }
        }
    }
    @ViewBuilder private func albumArtwork(entry: QueueEntry) -> some View {
        if let urlString = entry.artworkURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill).frame(width: 60, height: 60).cornerRadius(8)
                default:
                    Image(systemName: "music.note").font(.system(size: 24)).frame(width: 60, height: 60).background(Color.gray.opacity(0.15)).cornerRadius(8)
                }
            }
        } else {
            Image(systemName: "music.note").font(.system(size: 24)).frame(width: 60, height: 60).background(Color.gray.opacity(0.15)).cornerRadius(8)
        }
    }

    private func trackStatusIcon(_ s: TrackProgressState) -> String { switch s { case .pending: return "circle"; case .downloading: return "arrow.down.circle"; case .completed: return "checkmark.circle.fill"; case .failed: return "xmark.circle.fill" } }
    private func trackStatusColor(_ s: TrackProgressState) -> Color { switch s { case .pending: return .secondary; case .downloading: return .accentColor; case .completed: return .green; case .failed: return .red } }
    private func trackStatusText(_ s: TrackProgressState) -> String { switch s { case .pending: return "Pending"; case .downloading: return "Downloading"; case .completed: return "Done"; case .failed: return "Failed" } }
}

// MARK: - Queue sidebar

private struct QueueSidebar: View {
    @ObservedObject var viewModel: QueueViewModel
    @Binding var selectedID: String?
    let onSelectEntry: (String) -> Void
    private var queue: DownloadQueue { viewModel.queue }
    var body: some View {
        VStack(spacing: 0) {
            List(selection: Binding(get: { selectedID }, set: { newID in if let id = newID { selectedID = id; onSelectEntry(id) } })) {
                if queue.entries.isEmpty { Text("Nothing queued. Paste a link and add it.").foregroundColor(.secondary) }
                else { ForEach(queue.entries) { entry in QueueRow(entry: entry, isSelected: selectedID == entry.sourceUrl, onRetry: { viewModel.retry(entry.sourceUrl) }, onCancel: { viewModel.cancel(entry.sourceUrl) }, onRemove: { viewModel.remove(entry.sourceUrl) }).tag(entry.sourceUrl) } }
            }.listStyle(.sidebar)
            Divider()
            HStack {
                Button { chooseOutputDirectory() } label: { Label((viewModel.outputDirectory as NSString).lastPathComponent, systemImage: "folder").lineLimit(1).truncationMode(.middle) }.buttonStyle(.borderless).help("Download directory: \(viewModel.outputDirectory)")
                Spacer()
                Text("\(queue.activeCount) active · \(queue.entries.count) queued").font(.caption).foregroundColor(.secondary)
            }.padding(8)
        }
    }
    private func chooseOutputDirectory() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false; panel.directoryURL = URL(fileURLWithPath: viewModel.outputDirectory)
        if panel.runModal() == .OK, let url = panel.url { viewModel.outputDirectory = url.path }
    }
}

private struct QueueRow: View {
    let entry: QueueEntry; let isSelected: Bool; let onRetry: () -> Void; let onCancel: () -> Void; let onRemove: () -> Void
    private var stateLabel: (String, Color) { switch entry.state { case .pending: return ("Pending", .secondary); case .active: return ("Downloading", .accentColor); case .done: return ("Done", .green); case .failed: return ("Failed", .red); case .paused: return ("Paused", .orange) } }
    private var isRetryable: Bool { if case .failed = entry.state { return true }; return entry.state == .paused }
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.title).lineLimit(1).fontWeight(isSelected ? .semibold : .regular)
                if let artist = entry.artist, !artist.isEmpty { Text(artist).font(.caption).foregroundColor(.secondary).lineLimit(1) }
                if entry.state == .active && entry.totalTracks > 1 { ProgressView(value: Double(entry.downloadedCount), total: Double(entry.totalTracks)); Text("\(entry.downloadedCount) of \(entry.totalTracks)").font(.caption2).foregroundColor(.secondary) }
                if case .failed(let msg) = entry.state, !msg.isEmpty { Text(msg).font(.caption2).foregroundColor(.red).lineLimit(2) }
            }
            Spacer()
            if entry.state == .active { ProgressView().controlSize(.small); Button(action: onCancel) { Image(systemName: "stop.circle") }.buttonStyle(.borderless).foregroundColor(.red).help("Cancel") }
            else { let (label, color) = stateLabel; Text(label).font(.caption2).foregroundColor(color); if isRetryable { Button(action: onRetry) { Image(systemName: "arrow.clockwise") }.buttonStyle(.borderless) }; Button(action: onRemove) { Image(systemName: "xmark.circle") }.buttonStyle(.borderless).foregroundColor(.secondary) }
        }.padding(.vertical, 4).background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear).cornerRadius(6)
    }
}

private struct SearchResultRow: View {
    let result: SearchResult
    var body: some View {
        HStack(spacing: 10) {
            artwork(url: result.artworkURL, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) { if result.isAlbum { Text("Album").font(.caption2).padding(.horizontal, 4).background(Color.blue.opacity(0.15)).cornerRadius(3).foregroundColor(.blue) }; Text(result.title ?? "Unknown").lineLimit(1); ExplicitBadge(status: result.explicitStatus) }
                Text(result.artist ?? "").font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer(); Image(systemName: "arrow.down.circle").foregroundColor(.secondary)
        }.contentShape(Rectangle())
    }
}

private struct ExplicitBadge: View {
    let status: ExplicitStatus
    var body: some View {
        switch status {
        case .explicit: Text("Explicit").font(.caption2).padding(.horizontal, 4).background(Color.red.opacity(0.15)).cornerRadius(3).foregroundColor(.red)
        case .clean: Text("Clean").font(.caption2).padding(.horizontal, 4).background(Color.green.opacity(0.15)).cornerRadius(3).foregroundColor(.green)
        case .unknown: EmptyView()
        }
    }
}

private struct PreviewCard: View {
    let metadata: TrackMetadata; let onDownload: () -> Void; let onCancel: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            artwork(url: metadata.artworkURL, size: 140)
            VStack(spacing: 4) { Text(metadata.title).font(.title2); Text(metadata.artist).foregroundColor(.secondary); Text(metadata.album).font(.caption).foregroundColor(.secondary) }
            ExplicitBadge(status: metadata.explicitStatus)
            HStack { Button("Cancel", action: onCancel); Button("Add to Queue", action: onDownload).buttonStyle(.borderedProminent) }
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SelectionList: View {
    @Binding var tracks: [SelectableTrack]; let artworkURL: String?; let title: String?; let onDownload: () -> Void; let onCancel: () -> Void
    private var selectedCount: Int { tracks.filter(\.selected).count }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) { artwork(url: artworkURL, size: 56); VStack(alignment: .leading, spacing: 2) { Text(title ?? "Select tracks").font(.headline).lineLimit(1); Text("Select tracks to download").font(.subheadline).foregroundColor(.secondary) }; Spacer() }.padding()
            Divider()
            List($tracks) { $track in Toggle(isOn: $track.selected) { Text([track.title, track.artist].compactMap { $0 }.joined(separator: " — ")).lineLimit(1) }.toggleStyle(.checkbox) }.listStyle(.inset)
            Divider()
            HStack {
                Button("Select All") { tracks = tracks.map { var t = $0; t.selected = true; return t } }
                Button("None") { tracks = tracks.map { var t = $0; t.selected = false; return t } }
                Spacer()
                Text("\(selectedCount) selected").foregroundColor(.secondary)
                Button("Cancel", action: onCancel)
                Button("Add \(selectedCount) to Queue", action: onDownload).buttonStyle(.borderedProminent).disabled(selectedCount == 0)
            }.padding()
        }
    }
}

@ViewBuilder private func artwork(url: String?, size: CGFloat) -> some View {
    if let urlString = url, let url = URL(string: urlString) {
        AsyncImage(url: url) { phase in switch phase { case .success(let image): image.resizable().aspectRatio(contentMode: .fill).frame(width: size, height: size).cornerRadius(6); default: Image(systemName: "music.note").font(.system(size: size * 0.4)).frame(width: size, height: size).background(Color.gray.opacity(0.15)).cornerRadius(6) } }
    } else { Image(systemName: "music.note").font(.system(size: size * 0.4)).frame(width: size, height: size).background(Color.gray.opacity(0.15)).cornerRadius(6) }
}
