import SwiftUI

enum LibraryTab: String, CaseIterable, Identifiable {
    case home = "INICIO", search = "BUSCAR", playlists = "PLAYLISTS", songs = "CANCIONES"
    var id: String { rawValue }
}
struct TerminalTabBar: View {
    @Binding var selection: LibraryTab
    var body: some View {
        HStack(spacing: 0) {
            ForEach(LibraryTab.allCases) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 7) {
                        Rectangle().fill(selection == tab ? CRTTheme.highlight : .clear).frame(height: 1)
                        Text(tab.rawValue).font(CRTTheme.mono(10)).tracking(0.7)
                            .foregroundStyle(selection == tab ? CRTTheme.highlight : CRTTheme.ink.opacity(0.6))
                    }.frame(maxWidth: .infinity, minHeight: 44)
                }.buttonStyle(.plain).accessibilityAddTraits(selection == tab ? [.isSelected] : [])
            }
        }.padding(.horizontal, CRTTheme.margin).background(CRTTheme.background)
    }
}
