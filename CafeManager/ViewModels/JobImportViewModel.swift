import SwiftUI
import UIKit

@MainActor
final class JobImportViewModel: ObservableObject {
    enum ImportMode {
        case url
        case manualPaste
    }

    enum ViewState {
        case idle
        case loading(String)
        case success(JobDescription)
        case linkedInDetected
        case error(String)
    }

    @Published var urlText = ""
    @Published var pasteText = ""
    @Published var importMode: ImportMode = .url
    @Published var viewState: ViewState = .idle
    @Published var copiedToClipboard = false
    @Published var showFullDescription = false
    @Published var showAllRequirements = false

    private let service = JobFetcherService()
    private var fetchTask: Task<Void, Never>?

    var isLoading: Bool {
        if case .loading = viewState { return true }
        return false
    }

    func fetchJob() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)

        var urlString = trimmed
        if !urlString.lowercased().hasPrefix("http") {
            urlString = "https://\(urlString)"
        }

        guard let url = URL(string: urlString), url.host != nil else {
            withAnimation { viewState = .error("Please enter a valid URL.") }
            return
        }

        fetchTask?.cancel()

        fetchTask = Task {
            withAnimation { viewState = .loading("Preparing...") }

            do {
                let (content, method) = try await service.fetchJobContent(from: url) { [weak self] status in
                    withAnimation { self?.viewState = .loading(status) }
                }

                guard !Task.isCancelled else { return }

                withAnimation { viewState = .loading("Parsing job details...") }
                try await Task.sleep(for: .milliseconds(500))

                guard !Task.isCancelled else { return }

                let job = JobFetcherService.parseContent(content, sourceURL: url, method: method)
                showFullDescription = false
                showAllRequirements = false
                withAnimation(.spring(response: 0.4)) { viewState = .success(job) }
            } catch {
                guard !Task.isCancelled else { return }
                if error is CancellationError { return }

                if let fetchError = error as? JobFetchError {
                    if case .linkedInDetected = fetchError {
                        withAnimation { viewState = .linkedInDetected }
                        return
                    }
                }

                withAnimation {
                    viewState = .error(error.localizedDescription)
                }
            }
        }
    }

    func processManualPaste() {
        let text = pasteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            withAnimation { viewState = .error("Please paste the job description text.") }
            return
        }

        let job = JobFetcherService.parseContent(text, sourceURL: nil, method: "Manual Input")
        showFullDescription = false
        showAllRequirements = false
        withAnimation(.spring(response: 0.4)) { viewState = .success(job) }
    }

    func reset() {
        fetchTask?.cancel()
        withAnimation {
            urlText = ""
            pasteText = ""
            viewState = .idle
            importMode = .url
            copiedToClipboard = false
            showFullDescription = false
            showAllRequirements = false
        }
    }

    func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        withAnimation { copiedToClipboard = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copiedToClipboard = false }
        }
    }

    func switchToManualPaste() {
        withAnimation {
            importMode = .manualPaste
            viewState = .idle
        }
    }

    func switchToURLMode() {
        withAnimation {
            importMode = .url
            viewState = .idle
        }
    }
}
