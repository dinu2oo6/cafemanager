import Foundation
import WebKit

enum JobPlatform {
    case linkedin, indeed, naukri, glassdoor, other

    static func detect(from url: URL) -> JobPlatform {
        let host = url.host?.lowercased() ?? ""
        if host.contains("linkedin") { return .linkedin }
        if host.contains("indeed") { return .indeed }
        if host.contains("naukri") { return .naukri }
        if host.contains("glassdoor") { return .glassdoor }
        return .other
    }
}

enum JobFetchError: LocalizedError {
    case linkedInDetected
    case invalidURL
    case fetchFailed(String)
    case emptyContent

    var errorDescription: String? {
        switch self {
        case .linkedInDetected:
            return "LinkedIn requires login to view job listings."
        case .invalidURL:
            return "The URL provided is not valid."
        case .fetchFailed(let message):
            return message
        case .emptyContent:
            return "Could not extract content from this page. Try pasting the description instead."
        }
    }
}

@MainActor
final class JobFetcherService {
    private var webView: WKWebView?
    private var webViewDelegate: WebViewNavigationDelegate?

    func fetchJobContent(from url: URL, onStatusUpdate: @escaping (String) -> Void) async throws -> (content: String, method: String) {
        let platform = JobPlatform.detect(from: url)
        if platform == .linkedin {
            throw JobFetchError.linkedInDetected
        }

        // Tier 1: Jina Reader
        onStatusUpdate("Connecting to page renderer...")
        if let content = try? await fetchViaJina(url: url),
           Self.isValidJobContent(content) {
            return (content, "Jina Reader")
        }

        // Tier 2: WKWebView fallback
        onStatusUpdate("Rendering page in browser...")
        if let content = try? await fetchViaWebView(url: url),
           Self.isValidJobContent(content) {
            return (content, "Web Renderer")
        }

        throw JobFetchError.emptyContent
    }

    // MARK: - Jina Reader API

    private func fetchViaJina(url: URL) async throws -> String {
        let jinaString = "https://r.jina.ai/\(url.absoluteString)"
        guard let jinaURL = URL(string: jinaString) else {
            throw JobFetchError.invalidURL
        }

        var request = URLRequest(url: jinaURL, timeoutInterval: 30)
        request.setValue("text/markdown", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw JobFetchError.fetchFailed("Page renderer returned an error.")
        }

        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - WKWebView Fallback

    private func fetchViaWebView(url: URL) async throws -> String {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 1080, height: 1920), configuration: config)
        webView = wv

        let delegate = WebViewNavigationDelegate()
        webViewDelegate = delegate
        wv.navigationDelegate = delegate

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            delegate.setContinuation(cont)
            wv.load(URLRequest(url: url))

            Task { @MainActor [weak delegate] in
                try? await Task.sleep(for: .seconds(15))
                delegate?.forceComplete()
            }
        }

        try await Task.sleep(for: .seconds(2))

        let text: String = try await withCheckedThrowingContinuation { cont in
            wv.evaluateJavaScript("document.body.innerText") { result, error in
                if let error {
                    cont.resume(throwing: error)
                } else {
                    cont.resume(returning: result as? String ?? "")
                }
            }
        }

        webView = nil
        webViewDelegate = nil
        return text
    }

    // MARK: - Content Validation

    private static let blockedPhrases = [
        "just a moment",
        "additional verification required",
        "verify you are human",
        "checking your browser",
        "cloudflare",
        "ray id",
        "access denied",
        "please enable javascript",
        "captcha",
        "bot detection",
        "security check",
        "blocked",
        "403 forbidden"
    ]

    private static let jobSignalPhrases = [
        "job description", "responsibilities", "requirements",
        "qualifications", "experience", "apply", "about the role",
        "what you'll do", "who you are", "about us", "benefits",
        "work experience", "employment type", "full-time", "part-time",
        "salary", "compensation", "location", "remote", "hybrid",
        "years of experience", "bachelor", "degree", "skills",
        "we are looking for", "you will", "your role", "the role",
        "job type", "posted", "description", "overview"
    ]

    private static func isValidJobContent(_ content: String) -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 200 else { return false }

        let lower = trimmed.lowercased()

        let blockedHits = blockedPhrases.filter { lower.contains($0) }.count
        if blockedHits >= 2 { return false }

        let jobSignalHits = jobSignalPhrases.filter { lower.contains($0) }.count
        if jobSignalHits < 2 { return false }

        return true
    }

    // MARK: - Content Parsing

    static func parseContent(_ content: String, sourceURL: URL?, method: String) -> JobDescription {
        let lines = content.components(separatedBy: .newlines)
        var title = ""
        var company = ""
        var location = ""
        var salary: String?
        var requirements: [String] = []
        var descriptionLines: [String] = []
        var inRequirements = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if inRequirements { inRequirements = false }
                continue
            }

            if trimmed.hasPrefix("# ") && title.isEmpty {
                title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                continue
            }

            let lower = trimmed.lowercased()

            if lower.contains("requirement") || lower.contains("qualification") ||
               lower.contains("what you'll need") || lower.contains("must have") ||
               lower.contains("skills required") || lower.contains("what we're looking for") {
                inRequirements = true
                continue
            }

            if company.isEmpty, lower.hasPrefix("company"), lower.contains(":") {
                company = extractValue(from: trimmed)
                continue
            }
            if location.isEmpty, lower.hasPrefix("location"), lower.contains(":") {
                location = extractValue(from: trimmed)
                continue
            }
            if salary == nil,
               (lower.hasPrefix("salary") || lower.hasPrefix("compensation") || lower.hasPrefix("pay range")),
               lower.contains(":") {
                salary = extractValue(from: trimmed)
                continue
            }

            let isBullet = trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") ||
                           trimmed.hasPrefix("* ") || trimmed.hasPrefix("· ")
            if isBullet {
                let text = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if inRequirements {
                    requirements.append(text)
                } else {
                    descriptionLines.append(trimmed)
                }
                continue
            }

            if inRequirements {
                requirements.append(trimmed)
            } else {
                descriptionLines.append(trimmed)
            }
        }

        return JobDescription(
            title: title.isEmpty ? "Job Listing" : title,
            company: company,
            location: location,
            description: descriptionLines.joined(separator: "\n"),
            requirements: requirements,
            salary: salary,
            rawContent: content,
            sourceURL: sourceURL,
            fetchMethod: method
        )
    }

    private static func extractValue(from line: String) -> String {
        let parts = line.components(separatedBy: ":")
        return parts.dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - WKWebView Navigation Delegate

private class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func setContinuation(_ cont: CheckedContinuation<Void, Error>) {
        continuation = cont
    }

    func forceComplete() {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(throwing: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(throwing: error)
    }
}
