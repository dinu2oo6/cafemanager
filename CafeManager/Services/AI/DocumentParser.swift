import CoreImage
import Foundation
import PDFKit
import UIKit
import Vision

enum DocumentParser {
    struct OCRBillItem {
        let name: String
        let quantity: Int
        let unit: String
        let costPrice: Double
        let expiryDate: Date?
    }

    // MARK: - PDF

    /// Extracts all text from a PDF file at the given URL.
    static func extractText(from url: URL) -> String? {
        guard let document = PDFDocument(url: url) else { return nil }
        var fullText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let text = page.string {
                fullText += text + "\n"
            }
        }
        return fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : fullText
    }

    // MARK: - Image

    /// Prepares image data and MIME type for sending to local multimodal models.
    static func prepareImage(_ image: UIImage, maxDimension: CGFloat = 1536) -> (data: Data, mimeType: String)? {
        let resized = resize(image, maxDimension: maxDimension)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { return nil }
        return (data, "image/jpeg")
    }

    /// OCR extraction from image with preprocessing and multi-pass recognition.
    static func extractText(from image: UIImage) async throws -> String {
        let preprocessed = preprocessForOCR(image)
        let resized = resize(preprocessed, maxDimension: 2200)
        guard let cgImage = resized.cgImage else {
            throw NSError(domain: "DocumentParser", code: 2001, userInfo: [
                NSLocalizedDescriptionKey: "Unable to process image for OCR."
            ])
        }

        let accurateText = try await performOCR(on: cgImage, level: .accurate, languageCorrection: true, minTextHeight: 0.008)

        if !accurateText.isEmpty { return accurateText }

        let fastText = try await performOCR(on: cgImage, level: .fast, languageCorrection: false, minTextHeight: 0.005)

        if fastText.isEmpty {
            throw NSError(domain: "DocumentParser", code: 2002, userInfo: [
                NSLocalizedDescriptionKey: "No readable text found in image. Try with better lighting and a clearer photo."
            ])
        }
        return fastText
    }

    private static func performOCR(on cgImage: CGImage, level: VNRequestTextRecognitionLevel, languageCorrection: Bool, minTextHeight: Float) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(3).first?.string }
                let text = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: text)
            }
            request.recognitionLevel = level
            request.usesLanguageCorrection = languageCorrection
            request.minimumTextHeight = minTextHeight
            request.recognitionLanguages = ["en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension else { return image }
        let scale = maxDimension / largestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }

    private static func preprocessForOCR(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        let context = CIContext(options: [.useSoftwareRenderer: false])
        var processed = ciImage

        if let colorFilter = CIFilter(name: "CIColorControls") {
            colorFilter.setValue(processed, forKey: kCIInputImageKey)
            colorFilter.setValue(1.3, forKey: kCIInputContrastKey)
            colorFilter.setValue(0.0, forKey: kCIInputSaturationKey)
            colorFilter.setValue(0.05, forKey: kCIInputBrightnessKey)
            if let output = colorFilter.outputImage { processed = output }
        }

        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(processed, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.6, forKey: kCIInputSharpnessKey)
            if let output = sharpenFilter.outputImage { processed = output }
        }

        guard let cgImage = context.createCGImage(processed, from: processed.extent) else { return image }
        return UIImage(cgImage: cgImage)
    }

    // MARK: - Bill parsing prompt

    /// Returns the prompt to send alongside a bill/receipt image so Gemini extracts line items.
    static var billParsingPrompt: String {
        """
        This is a supplier bill/receipt. Extract each line item and then update inventory using tools.

        For each line item:
        - item_name
        - quantity
        - unit (kg/liters/pcs etc)
        - cost_price (buying price per unit)
        - selling_price (if missing use cost_price)
        - expiry_date (if present, format YYYY-MM-DD)
        - supplier_name (if visible)

        Tool rules:
        - If item exists: call update_stock_quantity, update_cost_price, update_selling_price.
        - If expiry date is present: call update_expiry_date.
        - If item does not exist: call add_inventory_item with reorder_level=10.
        - Never claim success unless tool calls were made.

        If not a bill/receipt, reply with normal description text.
        """
    }

    /// Returns the prompt for a PDF document (bill, invoice, etc.)
    static func pdfPrompt(text: String) -> String {
        """
        The following text was extracted from a supplier PDF (invoice/delivery note/purchase record).
        Parse all valid line items and update inventory via tools.

        Required extraction per line item:
        - item_name, quantity, unit, cost_price, selling_price (or same as cost), supplier_name (if present), expiry_date (if present)

        Use these operations:
        - Existing item: update_stock_quantity + update_cost_price + update_selling_price
        - Expiry present: update_expiry_date
        - New item: add_inventory_item (reorder_level=10)
        - Never output fake success without calling tools.

        --- DOCUMENT CONTENT ---
        \(text.prefix(4000))
        --- END ---
        """
    }

    /// Prompt for OCR text extracted from an image receipt.
    static func ocrBillPrompt(text: String) -> String {
        """
        The following text was OCR-extracted from a supplier bill/receipt image.
        Parse valid line items and update inventory via tools.

        Required fields per line item:
        - item_name, quantity, unit, cost_price, selling_price (or same as cost), supplier_name (if present), expiry_date (if present)

        Tool rules:
        - Existing item: update_stock_quantity + update_cost_price + update_selling_price
        - Expiry present: update_expiry_date with YYYY-MM-DD
        - New item: add_inventory_item with reorder_level=10
        - Never output fake success without calling tools.

        --- OCR CONTENT ---
        \(text.prefix(5000))
        --- END ---
        """
    }

    static func extractBillItems(fromOCRText text: String) -> [OCRBillItem] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var items: [OCRBillItem] = []
        var lastItemIndex: Int?

        for index in lines.indices {
            let line = lines[index]
            let lower = line.lowercased()

            if lower.hasPrefix("exp"), let idx = lastItemIndex, let expiry = parseDateFromLine(line) {
                let current = items[idx]
                items[idx] = OCRBillItem(
                    name: current.name,
                    quantity: current.quantity,
                    unit: current.unit,
                    costPrice: current.costPrice,
                    expiryDate: expiry
                )
                continue
            }

            if lower.contains("subtotal") || lower.contains("total") || lower.contains("tax") ||
                lower.contains("amount") || lower.contains("unit price") || lower.contains("cashier") ||
                lower.contains("bill no") || lower.contains("date") || lower.contains("time") {
                continue
            }

            // Detect item header first (robust against column OCR noise)
            // Examples:
            // "1. Milk (1 Litre) 1 ₹2.49 ₹2.49"
            // "Coffee (250g)"
            let headerPattern = #"^(?:\d{1,2}\s*[\.\)]\s*)?([A-Za-z][A-Za-z\s&\-/]+?)\s*\(([^)]+)\)"#
            guard let headerRegex = try? NSRegularExpression(pattern: headerPattern, options: [.caseInsensitive]) else { continue }
            let nsLine = line as NSString
            let lineRange = NSRange(location: 0, length: nsLine.length)
            guard let match = headerRegex.firstMatch(in: line, options: [], range: lineRange),
                  let nameRange = Range(match.range(at: 1), in: line),
                  let unitRange = Range(match.range(at: 2), in: line) else {
                continue
            }

            let rawName = String(line[nameRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let unitDescriptor = String(line[unitRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalizeUnit(fromDescriptor: unitDescriptor)
            let cleanName = cleanItemName(rawName)
            guard !cleanName.isEmpty else { continue }

            // Collect local OCR context (same line + next 2 lines) for qty/price tokens.
            let context = [line, lines[safe: index + 1], lines[safe: index + 2]]
                .compactMap { $0 }
                .joined(separator: " ")
            let (quantity, price) = extractQuantityAndPrice(from: context)

            if cleanName.isEmpty || price <= 0 { continue }
            items.append(OCRBillItem(
                name: cleanName,
                quantity: max(quantity, 1),
                unit: normalized,
                costPrice: price,
                expiryDate: nil
            ))
            lastItemIndex = items.count - 1
        }

        return items
    }

    private static func cleanItemName(_ raw: String) -> String {
        raw.replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeUnit(fromDescriptor descriptor: String) -> String {
        let lower = descriptor.lowercased()
        if lower.contains("kg") || lower.contains("kilogram") { return "kg" }
        if lower.contains("g") || lower.contains("gram") { return "g" }
        if lower.contains("litre") || lower.contains("liter") || lower == "l" || lower.contains(" l") { return "L" }
        if lower.contains("ml") { return "ml" }
        if lower.contains("piece") || lower.contains("pcs") || lower.contains("pc") { return "pcs" }
        return "pcs"
    }

    private static func parseDateFromLine(_ line: String) -> Date? {
        let formats = ["dd MMM yyyy", "dd-MMM-yyyy", "yyyy-MM-dd", "dd/MM/yyyy", "MM/dd/yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let raw = line
            .replacingOccurrences(of: "EXP:", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "EXP", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        for format in formats {
            formatter.dateFormat = format
            if let d = formatter.date(from: raw) { return d }
        }
        return nil
    }

    private static func extractQuantityAndPrice(from text: String) -> (Int, Double) {
        let numberPattern = #"\d+(?:\.\d{1,2})?"#
        guard let regex = try? NSRegularExpression(pattern: numberPattern) else { return (1, 0) }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: text, options: [], range: range)
        let values: [Double] = matches.compactMap {
            Double(ns.substring(with: $0.range))
        }
        guard !values.isEmpty else { return (1, 0) }

        var qty = 1
        var price = 0.0

        for value in values {
            if qty == 1, value >= 1, value <= 500, value.rounded() == value {
                qty = Int(value)
                continue
            }
            if value > 0, value <= 100000 {
                if value.rounded() != value || price == 0 {
                    price = value
                    if value.rounded() != value { break }
                }
            }
        }
        return (max(qty, 1), price)
    }

    // MARK: - Multi-strategy item extraction

    static func extractItemsMultiStrategy(from text: String) -> [OCRBillItem] {
        let billItems = extractBillItems(fromOCRText: text)
        if billItems.count >= 2 { return billItems }

        let quantifiedItems = extractFromQuantifiedList(text)
        if quantifiedItems.count >= 2 { return quantifiedItems }

        if !billItems.isEmpty { return billItems }
        if !quantifiedItems.isEmpty { return quantifiedItems }

        let simpleItems = extractFromSimpleList(text)
        return simpleItems
    }

    private static let unitPattern = #"(kg|kilogram|kilograms|g|gram|grams|litre|litres|liter|liters|L|ml|pcs|pieces?|packets?|boxes?|dozen|dz|units?|bags?|bottles?|cans?|tins?|packs?|cartons?|rolls?|bundles?|cups?|tubs?)"#

    private static func extractFromQuantifiedList(_ text: String) -> [OCRBillItem] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var items: [OCRBillItem] = []
        let pattern = #"^(?:\d{1,3}\s*[\.\)\-]\s*)?([A-Za-z][A-Za-z\s&\-/'.,]+?)\s*[-–—:x×]?\s*(\d+(?:\.\d+)?)\s*"# + unitPattern
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }

        for line in lines {
            let lower = line.lowercased()
            if isMetadataLine(lower) { continue }

            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            guard let match = regex.firstMatch(in: line, options: [], range: range),
                  match.numberOfRanges >= 4,
                  let nameRange = Range(match.range(at: 1), in: line),
                  let qtyRange = Range(match.range(at: 2), in: line),
                  let unitRange = Range(match.range(at: 3), in: line) else {
                continue
            }

            let name = cleanItemName(String(line[nameRange]))
            guard !name.isEmpty, name.count >= 2 else { continue }
            let qty = Int(Double(String(line[qtyRange])) ?? 1)
            let unit = normalizeUnit(fromDescriptor: String(line[unitRange]))

            let afterMatch = String(line[unitRange.upperBound...])
            let price = extractPrice(from: afterMatch)

            items.append(OCRBillItem(name: name, quantity: max(qty, 1), unit: unit, costPrice: price, expiryDate: nil))
        }
        return items
    }

    private static func extractFromSimpleList(_ text: String) -> [OCRBillItem] {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var items: [OCRBillItem] = []
        let bulletPattern = #"^(?:\d{1,3}\s*[\.\)\-]\s*|[-•*]\s*|[>]\s*)?(.+)$"#
        guard let bulletRegex = try? NSRegularExpression(pattern: bulletPattern) else { return [] }

        for line in lines {
            let lower = line.lowercased()
            if isMetadataLine(lower) { continue }
            if line.count < 2 || line.count > 80 { continue }

            let nsLine = line as NSString
            let range = NSRange(location: 0, length: nsLine.length)
            guard let match = bulletRegex.firstMatch(in: line, options: [], range: range),
                  let contentRange = Range(match.range(at: 1), in: line) else { continue }

            var content = String(line[contentRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }

            var qty = 0
            var unit = "pcs"
            var price = 0.0

            let inlineQtyPattern = #"\s+(\d+(?:\.\d+)?)\s*"# + unitPattern
            if let inlineRegex = try? NSRegularExpression(pattern: inlineQtyPattern, options: [.caseInsensitive]) {
                let nsContent = content as NSString
                let cRange = NSRange(location: 0, length: nsContent.length)
                if let inlineMatch = inlineRegex.firstMatch(in: content, options: [], range: cRange),
                   let qRange = Range(inlineMatch.range(at: 1), in: content),
                   let uRange = Range(inlineMatch.range(at: 2), in: content) {
                    qty = Int(Double(String(content[qRange])) ?? 0)
                    unit = normalizeUnit(fromDescriptor: String(content[uRange]))
                    let matchRange = Range(inlineMatch.range, in: content)!
                    let afterUnit = String(content[matchRange.upperBound...])
                    price = extractPrice(from: afterUnit)
                    content = String(content[..<matchRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            let name = cleanItemName(content)
            guard !name.isEmpty, name.count >= 2 else { continue }
            guard name.first?.isLetter == true else { continue }
            guard !name.lowercased().hasPrefix("total") else { continue }

            items.append(OCRBillItem(name: name, quantity: qty, unit: unit, costPrice: price, expiryDate: nil))
        }
        return items
    }

    private static func isMetadataLine(_ lower: String) -> Bool {
        let keywords = ["subtotal", "total", "tax", "gst", "cgst", "sgst", "amount due",
                        "unit price", "cashier", "bill no", "invoice", "receipt",
                        "thank you", "visit again", "phone", "tel:", "email:",
                        "address", "payment", "change", "balance"]
        return keywords.contains(where: { lower.contains($0) })
    }

    private static func extractPrice(from text: String) -> Double {
        let pricePattern = #"[₹$@Rs\.]*\s*(\d+(?:\.\d{1,2})?)"#
        guard let regex = try? NSRegularExpression(pattern: pricePattern) else { return 0 }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let numRange = Range(match.range(at: 1), in: text) else { return 0 }
        return Double(String(text[numRange])) ?? 0
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
