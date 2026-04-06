import SwiftUI

// MARK: - ToastView

struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            // notionText (#191919) background — opaque, no blur, no gradient
            .background(Color.notionText, in: Capsule())
            .onAppear {
                Task {
                    try await Task.sleep(for: .seconds(2))
                    withAnimation {
                        isShowing = false
                    }
                }
            }
    }
}

// MARK: - ViewModifier

private struct ToastModifier: ViewModifier {
    let message: String
    @Binding var isShowing: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if isShowing {
                    ToastView(message: message, isShowing: $isShowing)
                        .transition(.opacity)
                        .padding(.bottom, 48)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isShowing)
    }
}

extension View {
    func toast(message: String, isShowing: Binding<Bool>) -> some View {
        modifier(ToastModifier(message: message, isShowing: isShowing))
    }
}

// MARK: - Previews

private struct ToastPreviewHost: View {
    @State var isShowing: Bool
    let message: String
    let label: String

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 16) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.notionSecondary)
                Button("Show toast") { isShowing = true }
                    .buttonStyle(.bordered)
            }
        }
        .toast(message: message, isShowing: $isShowing)
    }
}

#Preview("Visible — saved") {
    ToastPreviewHost(
        isShowing: true,
        message: String(localized: "Saved to notebook."),
        label: "Toast appears, then auto-dismisses after 2 s"
    )
}

#Preview("Hidden — no text") {
    ToastPreviewHost(
        isShowing: false,
        message: String(localized: "No text found in this photo."),
        label: "Tap the button to trigger the toast"
    )
}
