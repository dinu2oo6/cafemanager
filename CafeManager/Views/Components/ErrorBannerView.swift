import SwiftUI

struct ErrorBannerView: View {
    let message: String
    var retryAction: (() -> Void)?
    var dismissAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.subheadline)

            Text(message)
                .font(.caption)
                .lineLimit(3)

            Spacer()

            if let retryAction {
                Button {
                    retryAction()
                } label: {
                    Text("Retry")
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(4)
                }
            }

            if let dismissAction {
                Button {
                    dismissAction()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.subheadline)
                }
            }
        }
        .foregroundColor(.white)
        .padding(12)
        .background(AppTheme.error)
        .cornerRadius(AppTheme.cornerRadius)
        .shadow(color: AppTheme.error.opacity(0.3), radius: 4, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.easeInOut, value: message)
    }
}
