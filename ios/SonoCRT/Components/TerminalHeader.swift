import SwiftUI

struct TerminalHeader: View {
    var title = "BIENVENIDO, NODO_07"
    var subtitle = "// 09:41 — sesión iniciada"
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("> " + title).font(CRTTheme.title(22)).foregroundStyle(CRTTheme.highlight)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle).font(CRTTheme.mono(11)).opacity(0.75)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
