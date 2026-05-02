import Foundation
import UIKit

@MainActor
final class AIAssistantViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var pendingConfirmation: PendingConfirmation?
    @Published var isSpeechEnabled = false
    @Published var hasRequestedPermissions = false

    let voiceManager = VoiceManager()
    private let aiService = CafeAIService()
    private var currentTask: Task<Void, Never>?

    init() {
        setupConfirmationHandler()
        addWelcomeMessage()
    }

    // MARK: - Setup

    private func addWelcomeMessage() {
        messages.append(ChatMessage(
            role: .assistant,
            text: "Hi! I'm your CafeManager AI assistant. I can control your entire cafe — inventory, orders, suppliers, customers, sales, and recipe cost analysis.\n\nTry things like:\n• \"How much does it cost to make a Masala Tea?\"\n• \"Show me the menu profitability ranking\"\n• \"What if milk price goes up by 20%?\"\n• \"Add 100 kg of coffee to inventory\"\n• \"Record a sale of 2 cappuccinos\"\n• \"Give me today's briefing\"\n\nJust tell me what you need — I'll ask for any missing details!"
        ))
    }

    private func setupConfirmationHandler() {
        aiService.confirmationHandler = { [weak self] action in
            guard let self else { return false }
            return await withCheckedContinuation { continuation in
                self.pendingConfirmation = PendingConfirmation(
                    title: action.title,
                    detail: action.detail,
                    onConfirm: { continuation.resume(returning: true) },
                    onDeny: { continuation.resume(returning: false) }
                )
            }
        }
    }

    // MARK: - Send text message

    func send(dataService: FirebaseDataService) {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        inputText = ""
        append(ChatMessage(role: .user, text: text))
        runQuery(dataService: dataService) {
            try await self.aiService.send(text: text, dataService: dataService)
        }
    }

    // MARK: - Send image

    func sendImage(_ image: UIImage, dataService: FirebaseDataService) {
        let userMsg = ChatMessage(role: .user, text: "Analyzing image...", image: image)
        append(userMsg)
        runQuery(dataService: dataService) {
            // Stage 1: OCR with preprocessing
            let extractedText: String
            do {
                extractedText = try await DocumentParser.extractText(from: image)
            } catch {
                return try await self.fallbackToVisionModel(image: image, dataService: dataService)
            }

            // Stage 2: Multi-strategy parsing
            let parsedItems = DocumentParser.extractItemsMultiStrategy(from: extractedText)

            if !parsedItems.isEmpty {
                let completeItems = parsedItems.filter { $0.costPrice > 0 && $0.quantity > 0 }
                let incompleteItems = parsedItems.filter { $0.costPrice <= 0 || $0.quantity <= 0 }

                var results: [String] = []

                if !completeItems.isEmpty {
                    let applied = await self.aiService.applyExtractedBillItems(completeItems, dataService: dataService)
                    results.append(applied)
                }

                if !incompleteItems.isEmpty {
                    let itemList = incompleteItems.enumerated().map { idx, item in
                        let qty = item.quantity > 0 ? "\(item.quantity) \(item.unit)" : "quantity needed"
                        return "\(idx + 1). \(item.name) (\(qty))"
                    }.joined(separator: "\n")
                    results.append("I also detected these items but need more details:\n\(itemList)\n\nPlease provide the quantities and cost prices so I can add them to inventory.")
                }

                return results.joined(separator: "\n\n")
            }

            // Stage 3: OCR text found but no items parsed - send to vision model with OCR context
            guard let prepared = DocumentParser.prepareImage(image) else {
                throw NSError(domain: "ImageProcessing", code: 3001, userInfo: [
                    NSLocalizedDescriptionKey: "Could not process this image. Please try with a clearer photo."
                ])
            }
            let enhancedPrompt = DocumentParser.ocrBillPrompt(text: extractedText)
            return try await self.aiService.send(
                text: enhancedPrompt,
                imageData: prepared.data,
                mimeType: prepared.mimeType,
                dataService: dataService
            )
        }
    }

    private func fallbackToVisionModel(image: UIImage, dataService: FirebaseDataService) async throws -> String {
        guard let prepared = DocumentParser.prepareImage(image) else {
            throw NSError(domain: "ImageProcessing", code: 3000, userInfo: [
                NSLocalizedDescriptionKey: "Unable to process this image. Please try with a clearer photo."
            ])
        }

        // Try single-shot vision extraction first (faster than tool-call loop)
        do {
            let visionItems = try await aiService.extractItemsViaVision(imageData: prepared.data)
            if !visionItems.isEmpty {
                let completeItems = visionItems.filter { $0.costPrice > 0 && $0.quantity > 0 }
                let incompleteItems = visionItems.filter { $0.costPrice <= 0 || $0.quantity <= 0 }

                var results: [String] = []
                if !completeItems.isEmpty {
                    let applied = await aiService.applyExtractedBillItems(completeItems, dataService: dataService)
                    results.append(applied)
                }
                if !incompleteItems.isEmpty {
                    let itemList = incompleteItems.enumerated().map { idx, item in
                        let qty = item.quantity > 0 ? "\(item.quantity) \(item.unit)" : "quantity needed"
                        return "\(idx + 1). \(item.name) (\(qty))"
                    }.joined(separator: "\n")
                    results.append("I detected these items but need more details:\n\(itemList)\n\nPlease provide the quantities and cost prices for these items.")
                }
                if !results.isEmpty { return results.joined(separator: "\n\n") }
            }
        } catch {
            // Vision extraction failed, fall through to tool-call approach
        }

        return try await aiService.send(
            text: DocumentParser.billParsingPrompt,
            imageData: prepared.data,
            mimeType: prepared.mimeType,
            dataService: dataService
        )
    }

    // MARK: - Send PDF

    func sendPDF(url: URL, dataService: FirebaseDataService) {
        guard let text = DocumentParser.extractText(from: url) else {
            append(ChatMessage(role: .assistant, text: "Couldn't read that PDF. Please try again with a text-based PDF."))
            return
        }
        let fileName = url.lastPathComponent
        append(ChatMessage(role: .user, text: "📄 Processing: \(fileName)"))
        let prompt = DocumentParser.pdfPrompt(text: text)
        runQuery(dataService: dataService) {
            try await self.aiService.send(text: prompt, dataService: dataService)
        }
    }

    // MARK: - Voice

    func toggleVoiceInput(dataService: FirebaseDataService) {
        if voiceManager.isListening {
            voiceManager.stopListening()
            let captured = voiceManager.transcript
            if !captured.isEmpty {
                inputText = captured
                send(dataService: dataService)
            }
        } else {
            Task {
                do {
                    try await voiceManager.startListening()
                } catch {
                    errorMessage = "Voice input failed: \(error.localizedDescription)"
                }
            }
        }
    }

    func toggleSpeech() {
        isSpeechEnabled.toggle()
        if !isSpeechEnabled { voiceManager.stopSpeaking() }
    }

    // MARK: - Suggestion chips

    var currentSuggestions: [String] {
        guard let lastMessage = messages.last, lastMessage.role == .assistant else {
            return defaultSuggestions
        }
        let text = lastMessage.text.lowercased()

        if text.contains("low stock") || text.contains("running low") {
            return ["Order low stock items", "Show demand forecast", "Show waste risks"]
        }
        if text.contains("order") && (text.contains("created") || text.contains("placed")) {
            return ["Show all orders", "Check inventory", "Today's briefing"]
        }
        if text.contains("sale") || text.contains("revenue") || text.contains("profit") {
            return ["Sales this week", "Sales this month", "Show all customers"]
        }
        if text.contains("added") && text.contains("inventory") {
            return ["Show inventory", "What's running low?", "Record a sale"]
        }
        if text.contains("cancelled") || text.contains("deleted") {
            return ["Show all orders", "Show inventory", "Today's briefing"]
        }
        if text.contains("recipe") || text.contains("cost analysis") || text.contains("ingredient") || text.contains("margin") {
            return ["Menu profitability", "What if milk price +20%?", "Show all recipes"]
        }
        if text.contains("welcome") || text.contains("hi!") || text.contains("briefing") || messages.count <= 1 {
            return defaultSuggestions
        }
        return contextualSuggestions
    }

    private var defaultSuggestions: [String] {
        ["Today's briefing", "What's running low?", "Show all recipes", "Today's sales", "Menu profitability"]
    }

    private var contextualSuggestions: [String] {
        ["Show inventory", "Waste risks", "Show recipes", "Sales summary", "Recipe cost analysis"]
    }

    // MARK: - Misc

    func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
        pendingConfirmation = nil
    }

    func clearConversation() {
        cancelCurrentRequest()
        messages.removeAll()
        aiService.resetChat()
        addWelcomeMessage()
    }

    func requestPermissionsIfNeeded() async {
        guard !hasRequestedPermissions else { return }
        hasRequestedPermissions = true
        await voiceManager.requestPermissions()
    }

    // MARK: - Private helpers

    private func append(_ message: ChatMessage) {
        messages.append(message)
    }

    private func runQuery(dataService: FirebaseDataService, query: @escaping () async throws -> String) {
        currentTask?.cancel()
        isLoading = true
        errorMessage = nil
        currentTask = Task {
            do {
                try Task.checkCancellation()
                let response = try await query()
                guard !Task.isCancelled else { return }
                append(ChatMessage(role: .assistant, text: response))
                if isSpeechEnabled {
                    voiceManager.speak(response)
                }
            } catch is CancellationError {
                // User cancelled, no error message needed
            } catch {
                guard !Task.isCancelled else { return }
                let msg = "Sorry, something went wrong: \(formatAIError(error))"
                append(ChatMessage(role: .assistant, text: msg))
                errorMessage = msg
            }
            isLoading = false
            pendingConfirmation = nil
        }
    }

    private func formatAIError(_ error: Error) -> String {
        let nsError = error as NSError
        var details = "\(nsError.localizedDescription) [\(nsError.domain):\(nsError.code)]"

        if let failureReason = nsError.localizedFailureReason, !failureReason.isEmpty {
            details += " Reason: \(failureReason)"
        }
        if let recoverySuggestion = nsError.localizedRecoverySuggestion, !recoverySuggestion.isEmpty {
            details += " Suggestion: \(recoverySuggestion)"
        }
        return details
    }
}
