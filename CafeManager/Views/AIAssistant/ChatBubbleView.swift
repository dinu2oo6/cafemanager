import SwiftUI

struct ChatBubbleView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .assistant {
                assistantAvatar
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if let image = message.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 220, height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius))
                }

                if !message.text.isEmpty {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(message.role == .user ? .white : AppTheme.textPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(bubbleBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
                        .textSelection(.enabled)
                }

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
        }
        .padding(.horizontal, AppTheme.padding)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
    }

    @ViewBuilder
    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(AppTheme.primaryGradient)
                .frame(width: 32, height: 32)
            Image(systemName: "sparkles")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private var bubbleBackground: some View {
        if message.role == .user {
            AppTheme.primaryGradient
        } else {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemBackground)],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}

// MARK: - Typing indicator

struct TypingIndicatorView: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle()
                    .fill(AppTheme.primaryGradient)
                    .frame(width: 32, height: 32)
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }

            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(AppTheme.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(phase == i ? 1.35 : 0.8)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Spacer(minLength: 48)
        }
        .padding(.horizontal, AppTheme.padding)
        .padding(.vertical, 4)
        .onAppear { phase = 2 }
    }
}
