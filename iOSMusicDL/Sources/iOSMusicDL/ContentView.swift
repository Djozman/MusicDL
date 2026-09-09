import SwiftUI

struct ContentView: View {
    @StateObject private var api = APIClient()
    @State private var link = ""
    @State private var preview: Preview?
    @State private var phase: Phase = .idle
    @State private var showServer = false
    @State private var serverInput = ""
    @State private var tokenInput = ""
    @State private var showShare = false
    @State private var shareURLs: [URL] = []
    @State private var completedTracks: Int = 0
    @State private var totalTracks: Int = 0
    @State private var currentTrackTitle: String = ""
    @State private var fetchStatus: String = ""

    enum Phase { case idle, loading, preview, downloading, done(String), error(String) }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                inputBar.padding()
                Divider()
                content.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("MusicDL")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { serverInput = api.baseURL; tokenInput = api.authToken; showServer = true } label: { Image(systemName: "server.rack") }
                }
            }
            .sheet(isPresented: $showShare) { if !shareURLs.isEmpty { ShareSheet(activityItems: shareURLs) } }
        }
        .alert("Server Settings", isPresented: $showServer) {
            TextField("https://your-tunnel.trycloudflare.com", text: $serverInput)
            SecureField("Auth token", text: $tokenInput)
            Button("Save") { api.baseURL = serverInput; api.authToken = tokenInput }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.right.square").foregroundColor(.secondary)
            TextField("Paste a music link…", text: $link).textFieldStyle(.roundedBorder).autocapitalization(.none).keyboardType(.URL).onSubmit { start() }
            Button("Go") { start() }.buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .idle:
            VStack(spacing: 8) {
                Image(systemName: "music.note").font(.system(size: 44)).foregroundColor(.secondary)
                Text("Paste a song/album/playlist link from Tidal, Spotify, YouTube, Deezer…").foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loading:
            VStack(spacing: 12) { ProgressView().controlSize(.large); Text("Fetching…").foregroundColor(.secondary) }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .preview:
            if let p = preview { previewCard(p) }
        case .downloading:
            downloadingView
        case .done(let msg):
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundColor(.green)
                Text(msg).foregroundColor(.secondary)
                if !shareURLs.isEmpty { Button("Save to Files") { showShare = true }.buttonStyle(.borderedProminent) }
                Button("Done") { reset() }.buttonStyle(.bordered)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        case .error(let msg):
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 44)).foregroundColor(.red)
                Text(msg).foregroundColor(.red).multilineTextAlignment(.center).padding(.horizontal)
                Button("Try Again") { reset() }.buttonStyle(.bordered)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var downloadingView: some View {
        VStack(spacing: 16) {
            if totalTracks > 1 { ProgressView(value: Double(completedTracks), total: Double(totalTracks)).progressViewStyle(.linear) } else { ProgressView().controlSize(.large) }
            
            if !fetchStatus.isEmpty {
                Text(fetchStatus).font(.headline)
            } else if totalTracks > 1 {
                Text("\(completedTracks) of \(totalTracks) tracks downloaded").font(.headline)
            }
            
            if !currentTrackTitle.isEmpty && fetchStatus.isEmpty {
                Text(currentTrackTitle).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            Text("Working…").foregroundColor(.secondary)
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func previewCard(_ p: Preview) -> some View {
        VStack(spacing: 16) {
            if let s = p.artworkURL, let u = URL(string: s) {
                AsyncImage(url: u) { img in img.resizable().aspectRatio(contentMode: .fill) } placeholder: { Image(systemName: "music.note").font(.system(size: 60)) }.frame(width: 140, height: 140).cornerRadius(10)
            }
            VStack(spacing: 4) {
                Text(p.title ?? "Unknown").font(.title2).multilineTextAlignment(.center)
                Text(p.artist ?? "").foregroundColor(.secondary)
                if p.trackCount != nil && (p.trackCount ?? 0) > 1 { Text("\(p.trackCount ?? 0) tracks").font(.caption).foregroundColor(.secondary) }
            }
            HStack { Button("Cancel") { reset() }; Button("Download") { download() }.buttonStyle(.borderedProminent) }
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func start() {
        let text = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        phase = .loading
        Task {
            do {
                let p = try await api.preview(text)
                if p.type == "error" { phase = .error(p.title ?? "Preview failed") }
                else { preview = p; phase = .preview }
            } catch { phase = .error("Could not reach server. Check URL and token.") }
        }
    }

    private func download() {
        let text = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        completedTracks = 0; totalTracks = preview?.trackCount ?? 1; currentTrackTitle = ""; shareURLs = []; fetchStatus = ""
        phase = .downloading
        Task {
            do {
                let started = try await api.download(text)
                guard let sid = started.session else { phase = .error("Server did not return a session ID."); return }
                while true {
                    try await Task.sleep(nanoseconds: 2_000_000_000)
                    let s = try await api.status(sid)
                    let st = s.status ?? "pending"
                    completedTracks = s.completed_tracks ?? 0
                    if let progress = s.track_progress, let last = progress.last(where: { $0.status == "downloading" }) { currentTrackTitle = last.title ?? "" }
                    if st == "done" {
                        let files = s.files ?? []
                        guard let base = s.base_url, !files.isEmpty else { phase = .error("No audio files were downloaded."); return }
                        
                        fetchStatus = "Fetching files..."
                        for (index, file) in files.enumerated() {
                            fetchStatus = "Fetching file \(index + 1) of \(files.count)..."
                            let url = try await api.fetchFile(base + file)
                            shareURLs.append(url)
                        }
                        
                        let msg = files.count == 1 ? "Downloaded \(files.first ?? "")" : "Downloaded \(files.count) tracks"
                        fetchStatus = ""
                        phase = .done(msg)
                        return
                    }
                    if st == "error" { phase = .error(s.message ?? "Download failed."); return }
                }
            } catch { phase = .error("Download failed: \(error.localizedDescription)") }
        }
    }

    private func reset() {
        preview = nil; shareURLs = []; link = ""; completedTracks = 0; totalTracks = 0; currentTrackTitle = ""; fetchStatus = ""; phase = .idle
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: activityItems, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
