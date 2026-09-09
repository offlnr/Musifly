import SwiftUI
import UIKit

/// A fixed-height title; only overflowing text scrolls, with a pause at each end.
struct MarqueeTitle: View {
    let text: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var started = Date()
    private let fontSize: CGFloat = 28
    private var textWidth: CGFloat {
        (text as NSString).size(withAttributes: [.font: UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)]).width
    }
    var body: some View {
        GeometryReader { geometry in
            let distance = max(0, textWidth - geometry.size.width)
            TimelineView(.animation(minimumInterval: 1.0 / 60, paused: distance == 0 || reduceMotion || scenePhase != .active)) { timeline in
                let travel = Double(distance) / 30
                let cycle = 4 + travel * 2
                let time = max(0, timeline.date.timeIntervalSince(started)).truncatingRemainder(dividingBy: cycle)
                let offset: CGFloat = reduceMotion || distance == 0 ? 0 : position(time: time, travel: travel, distance: distance)
                Text(text)
                    .font(.system(size: fontSize, weight: .regular, design: .monospaced))
                    .foregroundStyle(CRTTheme.highlight)
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: -offset)
                    .frame(width: geometry.size.width, height: 36, alignment: .leading)
            }
        }
        .frame(height: 36)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .onChange(of: text) { _, _ in started = Date() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { started = Date() } }
        .onAppear { started = Date() }
    }
    private func position(time: Double, travel: Double, distance: CGFloat) -> CGFloat {
        if time < 2 { return 0 }
        if time < 2 + travel { return CGFloat((time - 2) / travel) * distance }
        if time < 4 + travel { return distance }
        return distance * CGFloat(1 - (time - 4 - travel) / travel)
    }
}
