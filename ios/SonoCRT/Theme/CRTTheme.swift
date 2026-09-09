import SwiftUI

enum CRTTheme {
    static let background = Color(red: 5/255, green: 8/255, blue: 5/255)
    static let panel = Color(red: 7/255, green: 16/255, blue: 7/255)
    static let ink = Color(red: 51/255, green: 1, blue: 102/255)
    static let highlight = Color(red: 170/255, green: 1, blue: 196/255)
    static let margin: CGFloat = 24
    static func mono(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }
    static func title(_ size: CGFloat = 24) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
}

struct CRTBorder: ViewModifier {
    @Environment(\.displayScale) private var scale
    var opacity: Double
    func body(content: Content) -> some View {
        content.overlay(Rectangle().strokeBorder(CRTTheme.ink.opacity(opacity), lineWidth: 1 / scale))
    }
}
extension View {
    func crtBorder(_ opacity: Double = 0.55) -> some View { modifier(CRTBorder(opacity: opacity)) }
}
