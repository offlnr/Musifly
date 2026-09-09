import SwiftUI

struct ConnectionView: View {
    @EnvironmentObject private var playback: PlaybackStore
    @State private var endpoint = ""
    @State private var token = ""
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                TerminalHeader(title: "BIBLIOTECA R2", subtitle: "// conexión privada")
                Text(playback.connected ? "CONECTADO" : "SIN CONEXIÓN CONFIGURADA").font(CRTTheme.mono(12))
                TextField("https://tu-servicio.workers.dev", text: $endpoint)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(CRTTheme.mono(12)).padding(14).crtBorder().accessibilityLabel("URL del servicio")
                SecureField("Clave de acceso a tu biblioteca", text: $token)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(CRTTheme.mono(12)).padding(14).crtBorder()
                TerminalButton(title: playback.isLoading ? "CONECTANDO…" : "CONECTAR") { playback.connect(endpoint: endpoint, token: token) }
                    .disabled(playback.isLoading)
                if playback.connected {
                    TerminalButton(title: "ACTUALIZAR BIBLIOTECA") { playback.reload() }.disabled(playback.isLoading)
                    TerminalButton(title: "DESCONECTAR") { playback.disconnect(); token = "" }
                }
                Text("La clave de acceso se guarda en el llavero de este iPhone. Usa la clave de la biblioteca, no una clave de tu cuenta Cloudflare.")
                    .font(CRTTheme.mono(11)).opacity(0.65)
                Text("MP3, M4A, AAC, WAV, AIFF, CAF y FLAC. La compatibilidad final depende de la codificación de cada archivo.")
                    .font(CRTTheme.mono(11)).opacity(0.65)
            }.padding(24)
        }.background(CRTTheme.background)
        .gestureBackNavigation()
            .onAppear { endpoint = R2Credentials.load()?.endpoint.absoluteString ?? "" }
            .onChange(of: playback.isLoading) { _, loading in if !loading && playback.connected { token = "" } }
    }
}
