import SwiftUI

struct TerminalButton: View {
    let title: String
    var active = false
    let action: () -> Void
    var body: some View {
        Button(action: action) { Text(title).font(CRTTheme.mono(12))
            .foregroundStyle(active ? CRTTheme.highlight : CRTTheme.ink)
            .padding(.horizontal, 12).frame(minHeight: 44).crtBorder(active ? 1 : 0.55)
        }.buttonStyle(.plain)
    }
}
struct TerminalSection: View {
    let title: String
    var body: some View { Text(title).font(CRTTheme.mono(10)).tracking(2).opacity(0.75).accessibilityAddTraits(.isHeader) }
}
struct TerminalToggle: View {
    let title: String
    @Binding var value: Bool
    var body: some View {
        Button { value.toggle() } label: {
            HStack {
                Text(title).font(CRTTheme.mono(12))
                Spacer()
                Text(value ? "[ ON]" : "[OFF]").font(CRTTheme.mono(12)).foregroundStyle(value ? CRTTheme.highlight : CRTTheme.ink.opacity(0.5))
            }.frame(minHeight: 44)
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityValue(value ? "Activado" : "Desactivado")
    }
}
