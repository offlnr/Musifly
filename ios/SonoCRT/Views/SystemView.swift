import SwiftUI

struct SystemView: View {
    @AppStorage("crt.scanlines") private var scanlines = true
    @AppStorage("demo.offline") private var offline = true
    @AppStorage("demo.mobile") private var mobile = false
    @AppStorage("demo.quality") private var quality = "LOSSLESS"
    @AppStorage("demo.equalizer") private var equalizer = "PLANO"
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                TerminalHeader(title: "SYS/NODO_07", subtitle: "// preferencias locales")
                HStack(spacing: 14) {
                    Text("07").font(CRTTheme.title()).frame(width: 54, height: 54).crtBorder()
                    Text("usuario: marta.nodo07\nplan: DEMO / LOCAL\nescuchado: 1 284 h").font(CRTTheme.mono(11)).lineSpacing(5)
                }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(CRTTheme.panel).crtBorder()
                NavigationLink { ConnectionView() } label: {
                    Text("BIBLIOTECA R2 >").font(CRTTheme.mono(12)).padding(14).crtBorder()
                }.buttonStyle(.plain)
                TerminalSection(title: "AJUSTES")
                setting("calidad_audio", selection: $quality, values: ["LOSSLESS", "ALTA", "ESTÁNDAR"])
                setting("ecualizador", selection: $equalizer, values: ["PLANO", "GRAVES", "VOCES"])
                TerminalToggle(title: "nodo_offline", value: $offline)
                TerminalToggle(title: "scanlines_ui", value: $scanlines)
                TerminalToggle(title: "datos_moviles", value: $mobile)
                Text("// Los ajustes de audio y red son preferencias de demostración. El efecto CRT sí se aplica a la interfaz.").font(CRTTheme.mono(11)).opacity(0.6)
            }.padding(24)
        }.background(CRTTheme.background)
        .gestureBackNavigation()
    }
    private func setting(_ title: String, selection: Binding<String>, values: [String]) -> some View {
        HStack {
            Text(title).font(CRTTheme.mono(12)); Spacer()
            Menu { ForEach(values, id: \.self) { value in Button(value) { selection.wrappedValue = value } } }
                label: { Text(selection.wrappedValue + " ▾").font(CRTTheme.mono(12)).frame(minHeight: 44) }
        }
    }
}
