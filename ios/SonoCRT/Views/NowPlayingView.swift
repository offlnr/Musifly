import SwiftUI

struct NowPlayingView: View {
    @ObservedObject var playback: PlaybackStore
    @Environment(\.dismiss) private var dismiss
    @State private var scrollTop: CGFloat = 0
    @State private var dragStartedAtTop: Bool?
    @AppStorage("crt.scanlines") private var scanlines = true
    private func transportButton(_ symbol: String, label: String, size: CGFloat, active: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: size, weight: .medium))
                .frame(width: 38, height: 38)
                .foregroundStyle(active ? CRTTheme.highlight : CRTTheme.ink)
                .frame(minWidth: 0, maxWidth: .infinity)
                .frame(height: size > 20 ? 68 : 48)
                .background(active ? CRTTheme.ink.opacity(0.18) : CRTTheme.panel)
                .crtBorder(active ? 1 : 0.55)
        }.buttonStyle(StaticPlaybackButtonStyle())
            .symbolEffectsRemoved()
            .transaction { transaction in
                transaction.animation = nil
                transaction.disablesAnimations = true
            }
            .accessibilityLabel(label)
            .accessibilityValue((symbol == "shuffle" || symbol == "repeat") ? (active ? "Activado" : "Desactivado") : "")
    }
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("CARGANDO AUDIO…").font(CRTTheme.mono(10))
                        .opacity(playback.isBuffering ? 1 : 0)
                        .accessibilityHidden(!playback.isBuffering)
                    Spacer()
                    Text("AUDIO: " + playback.audioOutputName).font(CRTTheme.mono(10)).lineLimit(1).minimumScaleFactor(0.7)
                }.frame(height: 16)
                if let error = playback.errorMessage { Text(error).font(CRTTheme.mono(11)) }
                AlbumArtwork(data: playback.track.artworkData).aspectRatio(1, contentMode: .fit)
                    .overlay(alignment: .bottom) {
                        GeometryReader { geometry in
                            VStack {
                                Spacer(minLength: 0)
                                SpectrumView(spectrum: playback.spectrum, isPlaying: playback.isPlaying && !playback.isBuffering)
                                    .frame(height: geometry.size.height * 0.45)
                            }
                        }.allowsHitTesting(false)
                    }
                    .clipped()
                MarqueeTitle(text: playback.track.title)
                Text(playback.track.artist).font(CRTTheme.mono(12)).lineLimit(1).opacity(0.75)
                if let album = playback.track.albumTitle { Text(album).font(CRTTheme.mono(12)).lineLimit(1).opacity(0.65) }
                PlaybackSeekBar(playback: playback)
                HStack(spacing: 8) {
                    transportButton("shuffle", label: "Aleatorio", size: 18, active: playback.shuffle) { playback.shuffle.toggle() }
                    transportButton("backward.end.fill", label: "Canción anterior", size: 27) { playback.previous() }
                    transportButton(playback.isPlaying ? "pause.fill" : "play.fill", label: playback.isPlaying ? "Pausar" : "Reproducir", size: 34) { playback.toggle() }
                    transportButton("forward.end.fill", label: "Canción siguiente", size: 27) { playback.next() }
                    transportButton("repeat", label: "Repetir", size: 18, active: playback.loop) { playback.loop.toggle() }
                }
                TerminalSection(title: "COLA DE REPRODUCCIÓN")
                ForEach(playback.queue) { track in
                    Button { playback.play(track) } label: {
                        HStack { Text(track.title); Spacer(); Text(DemoCatalog.time(track.duration)) }.font(CRTTheme.mono(11)).frame(minHeight: 44)
                    }.buttonStyle(.plain).playlistMenu(for: track)
                }
            }.padding(24)
                .background(GeometryReader { geometry in
                    Color.clear.preference(key: PlayerScrollTop.self, value: geometry.frame(in: .named("playerScroll")).minY)
                })
        }
        .coordinateSpace(name: "playerScroll")
        .onPreferenceChange(PlayerScrollTop.self) { scrollTop = $0 }
        .simultaneousGesture(DragGesture(minimumDistance: 20)
            .onChanged { value in
                if dragStartedAtTop == nil { dragStartedAtTop = scrollTop >= -2 }
            }
            .onEnded { value in
                defer { dragStartedAtTop = nil }
                if dragStartedAtTop == true,
                   value.translation.height > 90,
                   value.translation.height > abs(value.translation.width) * 1.5 {
                    dismiss()
                }
            })
        .background(CRTTheme.background).foregroundStyle(CRTTheme.ink).tint(CRTTheme.ink)
            .overlay { if scanlines { CRTOverlay().ignoresSafeArea() } }
            .preferredColorScheme(.dark)
    }
}

private struct PlayerScrollTop: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct StaticPlaybackButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
