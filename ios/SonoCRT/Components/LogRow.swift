import SwiftUI

struct LogRow: View {
    let entry: LogEntry
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.time).opacity(0.6)
            Text(entry.message).fixedSize(horizontal: false, vertical: true)
        }.font(CRTTheme.mono(11)).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) {
                GeometryReader { proxy in
                    Path { path in
                        path.move(to: .zero)
                        path.addLine(to: CGPoint(x: proxy.size.width, y: 0))
                    }.stroke(CRTTheme.ink.opacity(0.3), style: StrokeStyle(lineWidth: 0.5, dash: [1, 3]))
                }.frame(height: 1)
            }
    }
}
