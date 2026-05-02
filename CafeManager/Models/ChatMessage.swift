import Foundation
import UIKit

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    var text: String
    var image: UIImage?
    var isAction: Bool = false
    let timestamp: Date = Date()

    enum Role {
        case user, assistant
    }
}

struct PendingConfirmation: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let onConfirm: () -> Void
    let onDeny: () -> Void
}
