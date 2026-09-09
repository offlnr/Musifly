import SwiftUI
import Combine

struct RootView: View {
    @StateObject private var playback = PlaybackStore()
    @StateObject private var playlists = PlaylistStore()
    @AppStorage("crt.scanlines") private var scanlines = true
    @State private var navigationID = UUID()
    @State private var selection: LibraryTab = .home
    init() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let index = args.firstIndex(of: "--preview-tab"), args.indices.contains(index + 1),
           let tab = LibraryTab(rawValue: args[index + 1]) {
            _selection = State(initialValue: tab)
        }
        #endif
    }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        VStack(spacing: 0) {
            NavigationStack {
            TabView(selection: $selection) {
                HomeView(playback: playback)
                    .tag(LibraryTab.home)
                SearchView(playback: playback)
                    .tag(LibraryTab.search)
                PlaylistsView(playback: playback)
                    .tag(LibraryTab.playlists)
                SongsView(playback: playback)
                    .tag(LibraryTab.songs)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .background(CRTTheme.background)
            }
            .id(navigationID)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            VStack(spacing: 8) {
                MiniPlayer(playback: playback)
                    .padding(.horizontal, 24)
                TerminalTabBar(selection: Binding(
                    get: { selection },
                    set: { tab in
                        selection = tab
                        navigationID = UUID()
                    }
                ))
            }
            .background(CRTTheme.background)
        }
        .tint(CRTTheme.ink).foregroundStyle(CRTTheme.ink)
        .background(CRTTheme.background.ignoresSafeArea())
        .overlay { if scanlines { CRTOverlay().ignoresSafeArea() } }
        .environmentObject(playback)
        .environmentObject(playlists)
        .fullScreenCover(isPresented: $playback.showingPlayer) { NowPlayingView(playback: playback).environmentObject(playlists) }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--preview-player") { playback.showingPlayer = true }
            #endif
        }
        .task {
            #if DEBUG
            // One-time local provisioning; credentials are not compiled into the app.
            let environment = ProcessInfo.processInfo.environment
            if let endpoint = environment["SONO_R2_ENDPOINT"], let token = environment["SONO_R2_TOKEN"] {
                playback.connect(endpoint: endpoint, token: token)
            } else { playback.restore() }
            #else
            playback.restore()
            #endif
        }
        .alert("Biblioteca", isPresented: Binding(get: { playback.errorMessage != nil }, set: { if !$0 { playback.errorMessage = nil } })) {
            Button("Aceptar", role: .cancel) { playback.errorMessage = nil }
        } message: { Text(playback.errorMessage ?? "") }
        .onReceive(timer) { _ in playback.tick() }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView().preferredColorScheme(.dark)
            .previewLayout(.fixed(width: 393, height: 852))
            .previewDisplayName("Referencia · 393 × 852")
    }
}
