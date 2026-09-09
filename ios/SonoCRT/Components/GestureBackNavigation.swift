import SwiftUI

private struct GestureBackNavigation: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .simultaneousGesture(DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    guard value.startLocation.x < 32,
                          value.translation.width > 80,
                          value.translation.width > abs(value.translation.height) * 1.5 else { return }
                    dismiss()
                })
            .accessibilityAction(.escape) { dismiss() }
    }
}

extension View {
    func gestureBackNavigation() -> some View { modifier(GestureBackNavigation()) }
}
