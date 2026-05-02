import Foundation

// MARK: - Action description passed to the confirmation handler

struct ActionDescription {
    let title: String
    let detail: String
}

private struct LocalFunctionCall {
    let name: String
    let args: JSONObject
}

private struct OllamaChatRequest: Encodable, Sendable {
    struct Message: Encodable, Sendable {
        let role: String
        let content: String
        let images: [String]?

        init(role: String, content: String, images: [String]? = nil) {
            self.role = role
            self.content = content
            self.images = images
        }
    }

    let model: String
    let messages: [Message]
    let stream: Bool
}

private struct OllamaChatResponse: Decodable, Sendable {
    struct Message: Decodable, Sendable {
        let role: String
        let content: String
    }

    let message: Message
}

// MARK: - CafeAIService

@MainActor
final class CafeAIService: ObservableObject {

    // Set by the ViewModel to intercept mutating tool calls for user confirmation.
    // Return true to proceed, false to cancel.
    var confirmationHandler: ((ActionDescription) async -> Bool)?

    private var messages: [OllamaChatRequest.Message] = []
    private var lastUserInput = ""
    private var currentModel = LocalLLMConfig.textModel
    private var requireToolCallResponse = false
    private var isBatchBillProcessing = false

    init() {
        resetChat()
    }

    func resetChat() {
        currentModel = LocalLLMConfig.textModel
        requireToolCallResponse = false
        isBatchBillProcessing = false
        messages = [
            .init(role: "system", content: LocalLLMConfig.systemInstruction),
            .init(role: "system", content: toolContract)
        ]
    }

    private func trimMessageHistory() {
        let systemCount = 2
        let maxConversation = 20
        guard messages.count > systemCount + maxConversation else { return }
        let system = Array(messages.prefix(systemCount))
        let recent = Array(messages.suffix(maxConversation))
        messages = system + recent
    }

    // MARK: - Text message

    func send(text: String, dataService: FirebaseDataService) async throws -> String {
        currentModel = LocalLLMConfig.textModel
        requireToolCallResponse = false
        isBatchBillProcessing = false
        lastUserInput = text
        messages.append(.init(role: "user", content: text))
        return try await runConversation(dataService: dataService)
    }

    func applyExtractedBillItems(_ items: [DocumentParser.OCRBillItem], dataService: FirebaseDataService) async -> String {
        guard !items.isEmpty else { return "No valid bill line items were detected." }

        var summaries: [String] = []
        for extracted in items {
            if let existing = findItem(extracted.name, in: dataService) {
                var updated = existing
                let oldQty = updated.quantity
                updated.quantity = max(0, updated.quantity + extracted.quantity)
                updated.costPrice = extracted.costPrice
                if updated.sellingPrice <= 0 {
                    updated.sellingPrice = extracted.costPrice
                }
                if let expiry = extracted.expiryDate {
                    updated.expiryDate = expiry
                }
                do {
                    try await dataService.updateInventoryItem(updated)
                    summaries.append("Updated \(updated.name): \(oldQty) -> \(updated.quantity) \(updated.unit), cost \(String(format: "%.2f", updated.costPrice))")
                } catch {
                    summaries.append("Action failed for \(updated.name): \(error.localizedDescription)")
                }
            } else {
                let item = InventoryItem(
                    name: extracted.name,
                    quantity: extracted.quantity,
                    unit: extracted.unit,
                    reorderLevel: 10,
                    costPrice: extracted.costPrice,
                    sellingPrice: extracted.costPrice,
                    supplierId: "",
                    dailyConsumption: [],
                    wasteRecord: [],
                    expiryDate: extracted.expiryDate
                )
                do {
                    try await dataService.addInventoryItem(item)
                    summaries.append("Added '\(item.name)' to inventory: \(item.quantity) \(item.unit)")
                } catch {
                    summaries.append("Action failed for \(item.name): \(error.localizedDescription)")
                }
            }
        }
        return summaries.joined(separator: "\n")
    }

    // MARK: - Multimodal message (image attached)

    func send(text: String, imageData: Data, mimeType: String, dataService: FirebaseDataService) async throws -> String {
        currentModel = LocalLLMConfig.visionModel
        requireToolCallResponse = true
        isBatchBillProcessing = true
        lastUserInput = text
        let base64Image = imageData.base64EncodedString()
        let visionPrompt = """
        \(text)

        Read this bill image and immediately call tools to update/add inventory.
        Process all line items in the bill, not just one.
        After finishing all item updates, respond exactly with: BILL_PROCESS_COMPLETE
        Do not answer in prose.
        Return only JSON tool calls in one of these formats:
        {"type":"tool_call","name":"tool_name","arguments":{...}}
        or {"name":"tool_name","arguments":{...}}
        """
        messages.append(.init(role: "user", content: visionPrompt, images: [base64Image]))
        return try await runConversation(dataService: dataService)
    }

    // MARK: - Local conversation loop (handles tool call loops)

    private func runConversation(dataService: FirebaseDataService) async throws -> String {
        var executedSummaries: [String] = []
        for _ in 0..<4 {
            trimMessageHistory()
            let assistantText = try await requestAssistantText()
            messages.append(.init(role: "assistant", content: assistantText))

            guard let call = parseToolCall(from: assistantText) else {
                let normalized = assistantText.trimmingCharacters(in: .whitespacesAndNewlines)

                // Prevent leaking internal loop text to the UI.
                if normalized.lowercased().contains("tool result for") {
                    messages.append(.init(
                        role: "system",
                        content: "Do not print tool result JSON. Respond with a concise user-facing summary only."
                    ))
                    continue
                }

                if requireToolCallResponse {
                    if isBatchBillProcessing && normalized.contains("BILL_PROCESS_COMPLETE") {
                        isBatchBillProcessing = false
                        requireToolCallResponse = false
                        if !executedSummaries.isEmpty {
                            return executedSummaries.joined(separator: "\n")
                        }
                        return "Bill processed."
                    }
                    messages.append(.init(
                        role: "system",
                        content: isBatchBillProcessing
                            ? "Continue processing remaining bill line items. Call the next tool now. When all items are done, reply BILL_PROCESS_COMPLETE."
                            : "You must call a tool now. Do not describe. Return only a valid JSON tool call."
                    ))
                    continue
                }

                if !executedSummaries.isEmpty {
                    return executedSummaries.joined(separator: "\n")
                }
                return normalized.isEmpty ? "Done." : normalized
            }

            if !isBatchBillProcessing {
                requireToolCallResponse = false
            }
            let toolResult = await dispatch(call: call, dataService: dataService)
            if let summary = userFacingSummary(from: toolResult) {
                executedSummaries.append(summary)
            }
            let serialized = toolResult.jsonString
            messages.append(.init(role: "system", content: "Tool result for \(call.name): \(serialized)"))

            if Self.readOnlyToolNames.contains(call.name) {
                let formatted = formatReadOnlyResult(toolResult)
                let response: String
                if !executedSummaries.isEmpty {
                    response = executedSummaries.joined(separator: "\n") + "\n\n" + formatted
                } else {
                    response = formatted
                }
                messages.append(.init(role: "assistant", content: response))
                return response
            }
        }

        if !executedSummaries.isEmpty {
            return executedSummaries.joined(separator: "\n")
        }
        return "I could not complete the request in time. Please try a more specific command."
    }

    private func requestAssistantText() async throws -> String {
        let currentMessages = messages
        let model = currentModel
        return try await Self.performOllamaRequest(model: model, messages: currentMessages)
    }

    private nonisolated static func performOllamaRequest(model: String, messages: [OllamaChatRequest.Message]) async throws -> String {
        guard let url = URL(string: LocalLLMConfig.baseURL + "/api/chat") else {
            throw NSError(domain: "CafeAIService", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Invalid Ollama base URL."])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body = OllamaChatRequest(model: model, messages: messages, stream: false)
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .cannotConnectToHost || urlError.code == .timedOut || urlError.code == .networkConnectionLost || urlError.code == .cannotFindHost {
            throw NSError(
                domain: "CafeAIService",
                code: 1002,
                userInfo: [
                    NSLocalizedDescriptionKey: "Cannot connect to AI server. Make sure Ollama is running at \(LocalLLMConfig.baseURL).",
                    NSLocalizedRecoverySuggestionErrorKey: "Start Ollama on your Mac and try again."
                ]
            )
        }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(
                domain: "CafeAIService",
                code: http.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Ollama request failed: HTTP \(http.statusCode) - \(serverMessage)"]
            )
        }

        let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        return decoded.message.content
    }

    func extractItemsViaVision(imageData: Data) async throws -> [DocumentParser.OCRBillItem] {
        let base64 = imageData.base64EncodedString()
        let extractionPrompt = """
        Extract ALL items from this image. Return a JSON array where each element has:
        {"name":"item name","quantity":number,"unit":"kg or L or pcs or g or ml","price":number}

        Rules:
        - Return ONLY the JSON array, no other text
        - If quantity is unclear, use 1
        - If unit is unclear, use "pcs"
        - If price is unclear, use 0
        - If no items found, return []
        """

        let msgs: [OllamaChatRequest.Message] = [
            .init(role: "system", content: "You are a precise data extraction assistant. Return only valid JSON arrays."),
            .init(role: "user", content: extractionPrompt, images: [base64])
        ]
        let responseText = try await Self.performOllamaRequest(model: LocalLLMConfig.visionModel, messages: msgs)
        return Self.parseVisionExtractionResult(responseText)
    }

    private static func parseVisionExtractionResult(_ text: String) -> [DocumentParser.OCRBillItem] {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = cleaned.firstIndex(of: "["),
              let end = cleaned.lastIndex(of: "]") else { return [] }

        let jsonStr = String(cleaned[start...end])
        guard let data = jsonStr.data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }

        return array.compactMap { dict -> DocumentParser.OCRBillItem? in
            guard let name = dict["name"] as? String, !name.isEmpty else { return nil }
            let quantity = (dict["quantity"] as? Int) ?? Int(dict["quantity"] as? Double ?? 1)
            let unit = dict["unit"] as? String ?? "pcs"
            let price = (dict["price"] as? Double) ?? Double(dict["price"] as? Int ?? 0)
            return DocumentParser.OCRBillItem(name: name, quantity: max(quantity, 1), unit: unit, costPrice: price, expiryDate: nil)
        }
    }

    private func parseToolCall(from content: String) -> LocalFunctionCall? {
        let trimmed = content
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let candidate = extractFirstJSONObject(from: trimmed) ?? trimmed
        guard let data = candidate.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if let type = json["type"] as? String,
           type == "tool_call",
           let name = json["name"] as? String {
            let args = extractArguments(from: json)
            return LocalFunctionCall(name: name, args: JSONObject.from(dictionary: args))
        }

        // Accept shorthand tool-call shape:
        // {"type":"create_purchase_order","item_name":"Coffee","quantity":100,...}
        if let type = json["type"] as? String,
           type != "tool_call",
           Self.supportedToolNames.contains(type) {
            let args = extractArguments(from: json)
            return LocalFunctionCall(name: type, args: JSONObject.from(dictionary: args))
        }

        // Accept direct shape:
        // {"name":"create_purchase_order","item_name":"Coffee","quantity":100,...}
        if let name = json["name"] as? String,
           Self.supportedToolNames.contains(name) {
            let args = extractArguments(from: json)
            return LocalFunctionCall(name: name, args: JSONObject.from(dictionary: args))
        }

        if let toolCalls = json["tool_calls"] as? [[String: Any]],
           let first = toolCalls.first,
           let name = first["name"] as? String {
            let args = extractArguments(from: first)
            return LocalFunctionCall(name: name, args: JSONObject.from(dictionary: args))
        }

        return nil
    }

    // MARK: - Function dispatch

    private func dispatch(call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        switch call.name {

        // Read-only — no confirmation needed
        case "get_inventory_status":
            return getInventoryStatus(filter: args["item_name"]?.stringValue, dataService: dataService)
        case "get_low_stock_items":
            return getLowStockItems(dataService: dataService)
        case "get_demand_forecast":
            guard let name = args["item_name"]?.stringValue else { return error("item_name required") }
            let days = args["days"]?.intValue ?? 7
            return getDemandForecast(itemName: name, days: days, dataService: dataService)
        case "get_waste_risks":
            return getWasteRisks(dataService: dataService)
        case "get_orders":
            return getOrders(statusFilter: args["status"]?.stringValue, dataService: dataService)
        case "get_suppliers":
            return getSuppliers(dataService: dataService)
        case "get_consumption_insights":
            return getConsumptionInsights(filter: args["item_name"]?.stringValue, dataService: dataService)
        case "get_item_pricing":
            return getItemPricing(itemName: args["item_name"]?.stringValue, dataService: dataService)

        // Mutating — require confirmation
        case "update_stock_quantity":
            return await mutate(
                action: ActionDescription(
                    title: "Update Stock",
                    detail: "Add \(args["quantity"]?.intValue ?? 0) \(args["unit"]?.stringValue ?? "") of \(args["item_name"]?.stringValue ?? "item") to inventory"
                ),
                call: call, dataService: dataService,
                execute: updateStockQuantity
            )
        case "add_inventory_item":
            return await mutate(
                action: ActionDescription(
                    title: "Add New Item",
                    detail: "Create inventory item: \(args["name"]?.stringValue ?? "unknown")"
                ),
                call: call, dataService: dataService,
                execute: addInventoryItem
            )
        case "create_purchase_order":
            let preparedOrder = preparePurchaseOrder(call: call, dataService: dataService)
            if let errorMessage = preparedOrder.errorMessage {
                return error(errorMessage)
            }
            guard let resolvedCall = preparedOrder.call,
                  let detail = preparedOrder.detail else {
                return error("Unable to prepare purchase order details.")
            }
            return await mutate(
                action: ActionDescription(
                    title: "Create Order",
                    detail: detail
                ),
                call: resolvedCall, dataService: dataService,
                execute: createPurchaseOrder
            )
        case "log_consumption":
            return await mutate(
                action: ActionDescription(
                    title: "Log Consumption",
                    detail: "Record \(args["amount"]?.intValue ?? 0) units consumed for \(args["item_name"]?.stringValue ?? "item")"
                ),
                call: call, dataService: dataService,
                execute: logConsumption
            )
        case "log_waste":
            return await mutate(
                action: ActionDescription(
                    title: "Log Waste",
                    detail: "Record \(args["amount"]?.intValue ?? 0) units wasted for \(args["item_name"]?.stringValue ?? "item") - reason: \(args["reason"]?.stringValue ?? "")"
                ),
                call: call, dataService: dataService,
                execute: logWaste
            )
        case "update_order_status":
            return await mutate(
                action: ActionDescription(
                    title: "Update Order",
                    detail: "Mark order for \(args["item_name"]?.stringValue ?? "item") as \(args["new_status"]?.stringValue ?? "updated")"
                ),
                call: call, dataService: dataService,
                execute: updateOrderStatus
            )
        case "update_cost_price":
            return await mutate(
                action: ActionDescription(
                    title: "Update Cost Price",
                    detail: "Set cost price of \(args["item_name"]?.stringValue ?? "item") to \(args["new_cost"]?.doubleValue ?? 0)"
                ),
                call: call, dataService: dataService,
                execute: updateCostPrice
            )
        case "update_selling_price":
            return await mutate(
                action: ActionDescription(
                    title: "Update Selling Price",
                    detail: "Set selling price of \(args["item_name"]?.stringValue ?? "item") to \(extractNewSellingPrice(from: args) ?? 0)"
                ),
                call: call, dataService: dataService,
                execute: updateSellingPrice
            )
        case "update_expiry_date":
            return await mutate(
                action: ActionDescription(
                    title: "Update Expiry Date",
                    detail: "Set expiry date of \(args["item_name"]?.stringValue ?? "item") to \(args["expiry_date"]?.stringValue ?? "")"
                ),
                call: call, dataService: dataService,
                execute: updateExpiryDate
            )
        case "delete_inventory_item":
            return await mutate(
                action: ActionDescription(
                    title: "Delete Item",
                    detail: "Delete \(args["item_name"]?.stringValue ?? "item") from inventory"
                ),
                call: call, dataService: dataService,
                execute: deleteInventoryItem
            )

        // MARK: - Order tools
        case "cancel_order":
            return await mutate(
                action: ActionDescription(
                    title: "Cancel Order",
                    detail: "Cancel order for \(args["item_name"]?.stringValue ?? "item")"
                ),
                call: call, dataService: dataService,
                execute: cancelOrder
            )
        case "delete_order":
            return await mutate(
                action: ActionDescription(
                    title: "Delete Order",
                    detail: "Delete order for \(args["item_name"]?.stringValue ?? "item")"
                ),
                call: call, dataService: dataService,
                execute: deleteOrder
            )

        // MARK: - Supplier tools
        case "add_supplier":
            return await mutate(
                action: ActionDescription(
                    title: "Add Supplier",
                    detail: "Add new supplier: \(args["name"]?.stringValue ?? "unknown")"
                ),
                call: call, dataService: dataService,
                execute: addSupplier
            )
        case "update_supplier":
            return await mutate(
                action: ActionDescription(
                    title: "Update Supplier",
                    detail: "Update supplier: \(args["name"]?.stringValue ?? "unknown")"
                ),
                call: call, dataService: dataService,
                execute: updateSupplier
            )
        case "delete_supplier":
            return await mutate(
                action: ActionDescription(
                    title: "Delete Supplier",
                    detail: "Delete supplier: \(args["name"]?.stringValue ?? "unknown")"
                ),
                call: call, dataService: dataService,
                execute: deleteSupplier
            )

        // MARK: - Customer tools
        case "get_customers":
            return getCustomers(filter: args["name"]?.stringValue, dataService: dataService)
        case "add_customer":
            return await mutate(
                action: ActionDescription(
                    title: "Add Customer",
                    detail: "Add new customer: \(args["name"]?.stringValue ?? "unknown")"
                ),
                call: call, dataService: dataService,
                execute: addCustomer
            )
        case "update_customer":
            return await mutate(
                action: ActionDescription(
                    title: "Update Customer",
                    detail: "Update customer: \(args["name"]?.stringValue ?? "unknown")"
                ),
                call: call, dataService: dataService,
                execute: updateCustomer
            )
        case "delete_customer":
            return await mutate(
                action: ActionDescription(
                    title: "Delete Customer",
                    detail: "Delete customer: \(args["name"]?.stringValue ?? "unknown")"
                ),
                call: call, dataService: dataService,
                execute: deleteCustomer
            )

        // MARK: - Sales tools
        case "get_sales_summary":
            return getSalesSummary(period: args["period"]?.stringValue, dataService: dataService)
        case "get_today_sales":
            return getTodaySales(dataService: dataService)
        case "get_top_selling_items":
            return getTopSellingItems(period: args["period"]?.stringValue, limit: args["limit"]?.intValue, dataService: dataService)
        case "record_sale":
            return await mutate(
                action: ActionDescription(
                    title: "Record Sale",
                    detail: "Record sale of \(args["quantity"]?.intValue ?? 0) x \(args["item_name"]?.stringValue ?? "item") via \(args["payment_method"]?.stringValue ?? "Cash")"
                ),
                call: call, dataService: dataService,
                execute: recordSale
            )

        // MARK: - Recipe & Cost Analysis tools
        case "get_recipes":
            return getRecipes(filter: args["name"]?.stringValue, dataService: dataService)
        case "analyze_product_cost":
            guard let recipeName = args["recipe_name"]?.stringValue else { return error("recipe_name required") }
            return analyzeProductCost(recipeName: recipeName, dataService: dataService)
        case "get_menu_profitability":
            return getMenuProfitability(dataService: dataService)
        case "what_if_price_change":
            guard let ingredientName = args["ingredient_name"]?.stringValue else { return error("ingredient_name required") }
            let percent = args["percent_change"]?.doubleValue ?? 10
            return whatIfPriceChange(ingredientName: ingredientName, percent: percent, dataService: dataService)
        case "add_recipe":
            return await mutate(
                action: ActionDescription(
                    title: "Add Recipe",
                    detail: "Create recipe: \(args["name"]?.stringValue ?? "unknown")"
                ),
                call: call, dataService: dataService,
                execute: addRecipe
            )
        case "delete_recipe":
            return await mutate(
                action: ActionDescription(
                    title: "Delete Recipe",
                    detail: "Delete recipe: \(args["recipe_name"]?.stringValue ?? "unknown")"
                ),
                call: call, dataService: dataService,
                execute: deleteRecipe
            )

        // MARK: - General
        case "get_daily_briefing":
            return getDailyBriefing(dataService: dataService)

        default:
            return error("Unknown function: \(call.name)")
        }
    }

    // Wraps mutating calls with a confirmation pause
    private func mutate(
        action: ActionDescription,
        call: LocalFunctionCall,
        dataService: FirebaseDataService,
        execute: (LocalFunctionCall, FirebaseDataService) async -> JSONObject
    ) async -> JSONObject {
        guard let handler = confirmationHandler else {
            return await execute(call, dataService)
        }
        let approved = await handler(action)
        guard approved else {
            return ["result": .string("Cancelled by user.")]
        }
        return await execute(call, dataService)
    }

    // MARK: - Read functions

    private func getInventoryStatus(filter: String?, dataService: FirebaseDataService) -> JSONObject {
        let items: [InventoryItem]
        if let filter {
            if let single = findItem(filter, in: dataService) {
                items = [single]
            } else {
                items = dataService.inventoryItems.filter { $0.name.localizedCaseInsensitiveContains(filter) }
            }
        } else {
            items = dataService.inventoryItems
        }
        if items.isEmpty { return ["result": .string("No inventory items found.")] }
        let list = items.map { item -> String in
            let days = item.daysUntilStockout == 999 ? "N/A" : "\(item.daysUntilStockout) days"
            let status = item.isLow ? " LOW" : ""
            return "\(item.name): \(item.quantity) \(item.unit) (reorder at \(item.reorderLevel)) - \(days) remaining\(status)"
        }.joined(separator: "\n")
        return ["inventory": .string(list), "total_items": .number(Double(items.count))]
    }

    private func getLowStockItems(dataService: FirebaseDataService) -> JSONObject {
        let low = dataService.inventoryItems.filter { $0.isLow }
        if low.isEmpty { return ["result": .string("All items are sufficiently stocked.")] }
        let list = low.map { "\($0.name): \($0.quantity)/\($0.reorderLevel) \($0.unit) - \($0.daysUntilStockout == 999 ? "N/A" : "\($0.daysUntilStockout) days") remaining" }.joined(separator: "\n")
        return ["low_stock_items": .string(list), "count": .number(Double(low.count))]
    }

    private func getDemandForecast(itemName: String, days: Int, dataService: FirebaseDataService) -> JSONObject {
        guard let item = findItem(itemName, in: dataService) else {
            return error("Item '\(itemName)' not found")
        }
        let forecasts = DemandForecaster.forecast(item: item, days: days)
        if forecasts.isEmpty { return ["result": .string("Not enough consumption data to forecast.")] }
        let summary = forecasts.map { "\($0.dayName): ~\(String(format: "%.1f", $0.predictedQuantity)) \(item.unit) (\($0.confidence)% confidence)" }.joined(separator: "\n")
        return ["item": .string(item.name), "forecast": .string(summary)]
    }

    private func getWasteRisks(dataService: FirebaseDataService) -> JSONObject {
        let risks = WastePredictor.predictAll(items: dataService.inventoryItems)
        if risks.isEmpty { return ["result": .string("No significant waste risks detected.")] }
        let summary = risks.map { "\($0.itemName): ~\(String(format: "%.1f", $0.predictedWasteQuantity)) \($0.unit) at risk (\($0.daysUntilExpiry) days to expiry) - \($0.recommendation)" }.joined(separator: "\n")
        return ["waste_risks": .string(summary), "count": .number(Double(risks.count))]
    }

    private func getOrders(statusFilter: String?, dataService: FirebaseDataService) -> JSONObject {
        let orders = statusFilter == nil
            ? dataService.orders
            : dataService.orders.filter { $0.status.rawValue.localizedCaseInsensitiveContains(statusFilter!) }
        if orders.isEmpty { return ["result": .string("No orders found.")] }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        let list = orders.map { "\($0.itemName) x \($0.quantity) from \($0.supplierName) - \($0.status.rawValue) (expected \(formatter.string(from: $0.expectedDeliveryDate)))" }.joined(separator: "\n")
        return ["orders": .string(list), "count": .number(Double(orders.count))]
    }

    private func getSuppliers(dataService: FirebaseDataService) -> JSONObject {
        if dataService.suppliers.isEmpty { return ["result": .string("No suppliers found.")] }
        let list = dataService.suppliers.map { "\($0.name) - lead time \($0.leadTimeInDays) days, \(String(format: "%.0f", $0.onTimeDeliveryRate))% on-time" }.joined(separator: "\n")
        return ["suppliers": .string(list)]
    }

    private func getConsumptionInsights(filter: String?, dataService: FirebaseDataService) -> JSONObject {
        let items: [InventoryItem]
        if let filter {
            if let single = findItem(filter, in: dataService) {
                items = [single]
            } else {
                items = dataService.inventoryItems.filter { $0.name.localizedCaseInsensitiveContains(filter) }
            }
        } else {
            items = dataService.inventoryItems
        }
        if items.isEmpty { return ["result": .string("No items found.")] }
        let insights = items.map { item -> String in
            let insight = ConsumptionAnalyzer.analyze(item: item)
            let trend = insight.trendPercentage > 0 ? "+\(String(format: "%.1f", insight.trendPercentage))%" : "\(String(format: "%.1f", insight.trendPercentage))%"
            let anomaly = insight.isAnomalous ? " Anomalous usage detected" : ""
            return "\(item.name): avg \(String(format: "%.1f", insight.dailyAverage)) \(item.unit)/day (weekday: \(String(format: "%.1f", insight.weekdayAverage)), weekend: \(String(format: "%.1f", insight.weekendAverage))), trend \(trend)\(anomaly)"
        }.joined(separator: "\n")
        return ["consumption_insights": .string(insights)]
    }

    private func getItemPricing(itemName: String?, dataService: FirebaseDataService) -> JSONObject {
        let items: [InventoryItem]
        if let itemName, !itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let single = findItem(itemName, in: dataService) {
                items = [single]
            } else {
                items = dataService.inventoryItems.filter { $0.name.localizedCaseInsensitiveContains(itemName) }
            }
        } else {
            items = dataService.inventoryItems
        }
        if items.isEmpty {
            return ["result": .string("No matching items found for pricing.")]
        }
        let list = items.map {
            "\($0.name): cost \(String(format: "%.2f", $0.costPrice)), selling \(String(format: "%.2f", $0.sellingPrice)) per \($0.unit)"
        }.joined(separator: "\n")
        return ["pricing": .string(list), "count": .number(Double(items.count))]
    }

    // MARK: - Mutating functions

    private func updateStockQuantity(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let name = args["item_name"]?.stringValue,
              let qty = args["quantity"]?.intValue else {
            return error("item_name and quantity required")
        }
        guard let item = findItem(name, in: dataService) else {
            return error("Item '\(name)' not found")
        }
        var updated = item
        updated.quantity = max(0, updated.quantity + qty)
        do {
            try await dataService.updateInventoryItem(updated)
            return ["result": .string("Updated \(item.name): \(item.quantity) -> \(updated.quantity) \(item.unit)")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func addInventoryItem(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let name = args["name"]?.stringValue,
              let qty = args["quantity"]?.intValue,
              let unit = args["unit"]?.stringValue,
              let reorder = args["reorder_level"]?.intValue,
              let cost = args["cost_price"]?.doubleValue,
              let sell = args["selling_price"]?.doubleValue else {
            return error("name, quantity, unit, reorder_level, cost_price, selling_price required")
        }
        let supplierName = args["supplier_name"]?.stringValue ?? ""
        let supplierId = dataService.suppliers.first(where: { $0.name.localizedCaseInsensitiveContains(supplierName) })?.id ?? ""
        let brand = args["brand"]?.stringValue
        let category = args["category"]?.stringValue.flatMap { ItemCategory(rawValue: $0) }
        let expiryDate = args["expiry_date"]?.stringValue.flatMap { parseDate($0) }
        let item = InventoryItem(
            name: name, brand: brand, category: category,
            quantity: qty, unit: unit, reorderLevel: reorder,
            costPrice: cost, sellingPrice: sell, supplierId: supplierId,
            dailyConsumption: [], wasteRecord: [], expiryDate: expiryDate
        )
        do {
            try await dataService.addInventoryItem(item)
            return ["result": .string("Added '\(name)' to inventory: \(qty) \(unit)")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func createPurchaseOrder(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let itemName = args["item_name"]?.stringValue,
              let qty = args["quantity"]?.intValue,
              let supplierName = args["supplier_name"]?.stringValue else {
            return error("item_name, quantity, supplier_name required")
        }
        guard let item = findItem(itemName, in: dataService),
              let supplier = dataService.suppliers.first(where: { $0.name.localizedCaseInsensitiveContains(supplierName) }),
              let supplierId = supplier.id else {
            return error("Item or supplier not found")
        }
        let leadDays = args["lead_days"]?.intValue ?? supplier.leadTimeInDays
        let expectedDelivery = Calendar.current.date(byAdding: .day, value: leadDays, to: Date()) ?? Date()
        let order = Order(
            itemId: item.id ?? "", itemName: item.name,
            quantity: qty, supplierId: supplierId, supplierName: supplier.name,
            orderDate: Date(), expectedDeliveryDate: expectedDelivery,
            status: .pending, unitPrice: item.costPrice, totalCost: item.costPrice * Double(qty)
        )
        do {
            try await dataService.addOrder(order)
            return ["result": .string("Order created: \(qty) units of \(item.name) from \(supplier.name), expected in \(leadDays) days")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func logConsumption(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let name = args["item_name"]?.stringValue, let amount = args["amount"]?.intValue else {
            return error("item_name and amount required")
        }
        guard let item = findItem(name, in: dataService),
              let itemId = item.id else {
            return error("Item '\(name)' not found")
        }
        do {
            try await dataService.logConsumption(itemId: itemId, amount: amount)
            return ["result": .string("Logged \(amount) \(item.unit) consumed for \(item.name)")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func logWaste(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let name = args["item_name"]?.stringValue,
              let amount = args["amount"]?.intValue,
              let reason = args["reason"]?.stringValue else {
            return error("item_name, amount, and reason required")
        }
        guard let item = findItem(name, in: dataService),
              let itemId = item.id else {
            return error("Item '\(name)' not found")
        }
        let entry = WasteEntry(quantity: amount, reason: reason, date: Date())
        do {
            try await dataService.logWaste(itemId: itemId, entry: entry)
            return ["result": .string("Logged \(amount) \(item.unit) waste for \(item.name) - \(reason)")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func updateOrderStatus(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let itemName = args["item_name"]?.stringValue,
              let statusStr = args["new_status"]?.stringValue,
              let newStatus = OrderStatus(rawValue: statusStr) else {
            return error("item_name and new_status (Pending/Ordered/Delivered) required")
        }
        guard var order = dataService.orders.first(where: { $0.itemName.localizedCaseInsensitiveContains(itemName) && $0.status != .delivered }) else {
            return error("Active order for '\(itemName)' not found")
        }
        order.status = newStatus
        do {
            try await dataService.updateOrder(order)
            return ["result": .string("Order for \(order.itemName) marked as \(newStatus.rawValue)")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func updateCostPrice(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let itemName = args["item_name"]?.stringValue,
              let newCost = extractNewCost(from: args),
              newCost >= 0 else {
            return error("item_name and non-negative new_cost required")
        }
        guard let item = findItem(itemName, in: dataService) else {
            return error("Item '\(itemName)' not found")
        }
        var updated = item
        let oldCost = updated.costPrice
        updated.costPrice = newCost
        do {
            try await dataService.updateInventoryItem(updated)
            return ["result": .string("Cost of \(updated.name) updated: \(String(format: "%.2f", oldCost)) -> \(String(format: "%.2f", newCost))")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func updateSellingPrice(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let itemName = args["item_name"]?.stringValue,
              let newPrice = extractNewSellingPrice(from: args),
              newPrice >= 0 else {
            return error("item_name and non-negative new_selling_price required")
        }
        guard let item = findItem(itemName, in: dataService) else {
            return error("Item '\(itemName)' not found")
        }
        var updated = item
        let oldPrice = updated.sellingPrice
        updated.sellingPrice = newPrice
        do {
            try await dataService.updateInventoryItem(updated)
            return ["result": .string("Selling price of \(updated.name) updated: \(String(format: "%.2f", oldPrice)) -> \(String(format: "%.2f", newPrice))")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func updateExpiryDate(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let itemName = args["item_name"]?.stringValue else {
            return error("item_name required")
        }
        guard let dateString = args["expiry_date"]?.stringValue ?? args["new_expiry_date"]?.stringValue,
              let expiryDate = parseDate(dateString) else {
            return error("expiry_date required in YYYY-MM-DD format")
        }
        guard let item = findItem(itemName, in: dataService) else {
            return error("Item '\(itemName)' not found")
        }
        var updated = item
        updated.expiryDate = expiryDate
        do {
            try await dataService.updateInventoryItem(updated)
            return ["result": .string("Expiry date of \(updated.name) set to \(isoDateString(expiryDate)).")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func deleteInventoryItem(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let itemName = args["item_name"]?.stringValue else {
            return error("item_name required")
        }
        guard let item = findItem(itemName, in: dataService),
              let itemId = item.id else {
            return error("Item '\(itemName)' not found")
        }
        do {
            try await dataService.deleteInventoryItem(itemId)
            return ["result": .string("Deleted \(item.name) from inventory.")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    // MARK: - Order mutations

    private func cancelOrder(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let itemName = args["item_name"]?.stringValue else {
            return error("item_name required")
        }
        guard var order = dataService.orders.first(where: { $0.itemName.localizedCaseInsensitiveContains(itemName) && $0.status != .delivered && $0.status != .cancelled }) else {
            return error("Active order for '\(itemName)' not found")
        }
        order.status = .cancelled
        do {
            try await dataService.updateOrder(order)
            return ["result": .string("Order for \(order.itemName) has been cancelled.")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func deleteOrder(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let itemName = args["item_name"]?.stringValue else {
            return error("item_name required")
        }
        guard let order = dataService.orders.first(where: { $0.itemName.localizedCaseInsensitiveContains(itemName) }),
              let orderId = order.id else {
            return error("Order for '\(itemName)' not found")
        }
        do {
            try await dataService.deleteOrder(orderId)
            return ["result": .string("Deleted order for \(order.itemName).")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    // MARK: - Supplier functions

    private func addSupplier(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let name = args["name"]?.stringValue,
              let email = args["email"]?.stringValue,
              let phone = args["phone"]?.stringValue,
              let address = args["address"]?.stringValue,
              let leadTime = args["lead_time_days"]?.intValue else {
            return error("name, email, phone, address, and lead_time_days required")
        }
        let paymentTerms = args["payment_terms"]?.stringValue ?? "Net 30"
        let supplier = Supplier(
            name: name, email: email, phone: phone, address: address,
            leadTimeInDays: leadTime, paymentTerms: paymentTerms,
            onTimeDeliveryRate: 80, totalAmountOwed: 0
        )
        do {
            try await dataService.addSupplier(supplier)
            return ["result": .string("Added supplier '\(name)' with \(leadTime)-day lead time.")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func updateSupplier(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let name = args["name"]?.stringValue else {
            return error("name required")
        }
        guard var supplier = dataService.suppliers.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) else {
            return error("Supplier '\(name)' not found")
        }
        var changes: [String] = []
        if let email = args["email"]?.stringValue { supplier.email = email; changes.append("email") }
        if let phone = args["phone"]?.stringValue { supplier.phone = phone; changes.append("phone") }
        if let address = args["address"]?.stringValue { supplier.address = address; changes.append("address") }
        if let leadTime = args["lead_time_days"]?.intValue { supplier.leadTimeInDays = leadTime; changes.append("lead time") }
        if let terms = args["payment_terms"]?.stringValue { supplier.paymentTerms = terms; changes.append("payment terms") }
        guard !changes.isEmpty else { return error("No fields to update") }
        do {
            try await dataService.updateSupplier(supplier)
            return ["result": .string("Updated \(supplier.name): \(changes.joined(separator: ", "))")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func deleteSupplier(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let name = args["name"]?.stringValue else {
            return error("name required")
        }
        guard let supplier = dataService.suppliers.first(where: { $0.name.localizedCaseInsensitiveContains(name) }),
              let supplierId = supplier.id else {
            return error("Supplier '\(name)' not found")
        }
        do {
            try await dataService.deleteSupplier(supplierId)
            return ["result": .string("Deleted supplier '\(supplier.name)'.")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    // MARK: - Customer functions

    private func getCustomers(filter: String?, dataService: FirebaseDataService) -> JSONObject {
        let customers = filter == nil
            ? dataService.customers
            : dataService.customers.filter { $0.name.localizedCaseInsensitiveContains(filter!) }
        if customers.isEmpty { return ["result": .string("No customers found.")] }
        let list = customers.map { c -> String in
            let tier = c.loyaltyTier.rawValue
            let visits = c.visitCount
            let spent = String(format: "%.0f", c.totalSpent)
            let churn = c.isChurnRisk ? " [CHURN RISK]" : ""
            return "\(c.name) - \(tier) tier, \(visits) visits, \u{20B9}\(spent) spent\(churn)"
        }.joined(separator: "\n")
        return ["customers": .string(list), "count": .number(Double(customers.count))]
    }

    private func addCustomer(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let name = args["name"]?.stringValue,
              let email = args["email"]?.stringValue,
              let phone = args["phone"]?.stringValue else {
            return error("name, email, and phone required")
        }
        let notes = args["notes"]?.stringValue
        let customer = Customer(
            name: name, email: email, phone: phone,
            totalSpent: 0, visitCount: 0,
            favoriteItems: [], notes: notes
        )
        do {
            try await dataService.addCustomer(customer)
            return ["result": .string("Added customer '\(name)'.")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func updateCustomer(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let name = args["name"]?.stringValue else {
            return error("name required")
        }
        guard var customer = dataService.customers.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) else {
            return error("Customer '\(name)' not found")
        }
        var changes: [String] = []
        if let email = args["email"]?.stringValue { customer.email = email; changes.append("email") }
        if let phone = args["phone"]?.stringValue { customer.phone = phone; changes.append("phone") }
        if let notes = args["notes"]?.stringValue { customer.notes = notes; changes.append("notes") }
        guard !changes.isEmpty else { return error("No fields to update") }
        do {
            try await dataService.updateCustomer(customer)
            return ["result": .string("Updated \(customer.name): \(changes.joined(separator: ", "))")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func deleteCustomer(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let name = args["name"]?.stringValue else {
            return error("name required")
        }
        guard let customer = dataService.customers.first(where: { $0.name.localizedCaseInsensitiveContains(name) }),
              let customerId = customer.id else {
            return error("Customer '\(name)' not found")
        }
        do {
            try await dataService.deleteCustomer(customerId)
            return ["result": .string("Deleted customer '\(customer.name)'.")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    // MARK: - Sales functions

    private func getSalesSummary(period: String?, dataService: FirebaseDataService) -> JSONObject {
        let calendar = Calendar.current
        let now = Date()
        let filtered: [SaleTransaction]
        let periodLabel: String

        switch period?.lowercased() {
        case "today":
            let start = calendar.startOfDay(for: now)
            filtered = dataService.sales.filter { $0.date >= start }
            periodLabel = "Today"
        case "week":
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            filtered = dataService.sales.filter { $0.date >= start }
            periodLabel = "Last 7 days"
        case "month":
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            filtered = dataService.sales.filter { $0.date >= start }
            periodLabel = "Last 30 days"
        default:
            filtered = dataService.sales
            periodLabel = "All time"
        }

        if filtered.isEmpty { return ["result": .string("No sales found for \(periodLabel).")] }
        let totalRevenue = filtered.reduce(0) { $0 + $1.totalAmount }
        let totalProfit = filtered.reduce(0) { $0 + $1.grossProfit }
        let totalOrders = filtered.count
        let totalItems = filtered.reduce(0) { $0 + $1.itemCount }
        let avgOrder = totalRevenue / Double(totalOrders)

        let summary = """
        \(periodLabel) Sales Summary:
        Orders: \(totalOrders) (\(totalItems) items)
        Revenue: \u{20B9}\(String(format: "%.0f", totalRevenue))
        Profit: \u{20B9}\(String(format: "%.0f", totalProfit))
        Avg Order: \u{20B9}\(String(format: "%.0f", avgOrder))
        """
        return ["summary": .string(summary)]
    }

    private func getTodaySales(dataService: FirebaseDataService) -> JSONObject {
        let sales = dataService.todaySales
        if sales.isEmpty { return ["result": .string("No sales recorded today yet.")] }
        let list = sales.map { sale -> String in
            let items = sale.items.map { "\($0.itemName) x\($0.quantity)" }.joined(separator: ", ")
            return "\(items) — \u{20B9}\(String(format: "%.0f", sale.totalAmount)) (\(sale.paymentMethod.rawValue))"
        }.joined(separator: "\n")
        let summary = "Today: \(sales.count) orders, \u{20B9}\(String(format: "%.0f", dataService.todayRevenue)) revenue, \u{20B9}\(String(format: "%.0f", dataService.todayProfit)) profit\n\n\(list)"
        return ["today_sales": .string(summary)]
    }

    private func getTopSellingItems(period: String?, limit: Int?, dataService: FirebaseDataService) -> JSONObject {
        let calendar = Calendar.current
        let now = Date()
        let filtered: [SaleTransaction]
        let periodLabel: String

        switch period?.lowercased() {
        case "today":
            filtered = dataService.todaySales
            periodLabel = "Today"
        case "week":
            let start = calendar.date(byAdding: .day, value: -7, to: now) ?? now
            filtered = dataService.sales.filter { $0.date >= start }
            periodLabel = "Last 7 days"
        case "month":
            let start = calendar.date(byAdding: .month, value: -1, to: now) ?? now
            filtered = dataService.sales.filter { $0.date >= start }
            periodLabel = "Last 30 days"
        default:
            filtered = dataService.sales
            periodLabel = "All time"
        }

        if filtered.isEmpty { return ["result": .string("No sales found for \(periodLabel).")] }

        var itemSales: [String: (quantity: Int, revenue: Double)] = [:]
        for sale in filtered {
            for item in sale.items {
                let key = item.itemName
                let existing = itemSales[key] ?? (quantity: 0, revenue: 0)
                itemSales[key] = (quantity: existing.quantity + item.quantity, revenue: existing.revenue + item.totalPrice)
            }
        }

        let cap = min(limit ?? 10, itemSales.count)
        let sorted = itemSales.sorted { $0.value.revenue > $1.value.revenue }
        let topItems = sorted.prefix(cap)
        let list = topItems.enumerated().map { idx, entry in
            "\(idx + 1). \(entry.key): \(entry.value.quantity) sold, \u{20B9}\(String(format: "%.0f", entry.value.revenue)) revenue"
        }.joined(separator: "\n")

        return ["top_items": .string("\(periodLabel) Top Selling Items:\n\(list)"), "count": .number(Double(cap))]
    }

    private func recordSale(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let itemName = args["item_name"]?.stringValue,
              let qty = args["quantity"]?.intValue else {
            return error("item_name and quantity required")
        }
        guard let item = findItem(itemName, in: dataService) else {
            return error("Item '\(itemName)' not found in inventory")
        }
        guard item.quantity >= qty else {
            return error("Not enough stock. Available: \(item.quantity) \(item.unit)")
        }
        let paymentStr = args["payment_method"]?.stringValue ?? "Cash"
        let paymentMethod = PaymentMethod(rawValue: paymentStr) ?? .cash
        let discount = args["discount"]?.doubleValue ?? 0
        let customerName = args["customer_name"]?.stringValue
        let customerId = customerName.flatMap { cName in
            dataService.customers.first(where: { $0.name.localizedCaseInsensitiveContains(cName) })?.id
        }

        let saleItem = SaleItem(
            itemId: item.id ?? "", itemName: item.name,
            itemSKU: item.sku, itemBrand: item.brand,
            quantity: qty, unitPrice: item.sellingPrice, costPrice: item.costPrice
        )
        let subtotal = saleItem.totalPrice
        let total = subtotal - discount

        let sale = SaleTransaction(
            items: [saleItem], subtotal: subtotal, discount: discount,
            totalAmount: total, paymentMethod: paymentMethod,
            customerName: customerName, customerId: customerId,
            date: Date()
        )
        do {
            try await dataService.addSale(sale)
            // Deduct from inventory
            if let itemId = item.id {
                try await dataService.logConsumption(itemId: itemId, amount: qty)
            }
            return ["result": .string("Sale recorded: \(qty) x \(item.name) = \u{20B9}\(String(format: "%.0f", total)) via \(paymentMethod.rawValue)")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    // MARK: - Recipe & Cost Analysis functions

    private func getRecipes(filter: String?, dataService: FirebaseDataService) -> JSONObject {
        let recipes: [Recipe]
        if let filter, !filter.trimmingCharacters(in: .whitespaces).isEmpty {
            recipes = dataService.recipes.filter { $0.name.localizedCaseInsensitiveContains(filter) }
        } else {
            recipes = dataService.recipes
        }
        if recipes.isEmpty { return ["result": .string("No recipes found. You can add recipes via the Recipe Cost Analysis screen or ask me to add one.")] }
        let list = recipes.map { recipe -> String in
            let breakdown = ProductCostAnalyzer.analyzeProduct(recipe: recipe, inventory: dataService.inventoryItems, sales: dataService.sales, allRecipes: dataService.recipes)
            let ingredients = recipe.ingredients.map { "\($0.itemName) (\(String(format: "%.2f", $0.quantity)) \($0.unit))" }.joined(separator: ", ")
            return "\(recipe.name) [\(recipe.category.rawValue)] — Sells: \u{20B9}\(String(format: "%.0f", recipe.sellingPrice)), Cost: \u{20B9}\(String(format: "%.2f", breakdown.trueProductionCost)), Margin: \(String(format: "%.0f", breakdown.marginPercentage))%, Ingredients: \(ingredients)"
        }.joined(separator: "\n")
        return ["recipes": .string(list), "count": .number(Double(recipes.count))]
    }

    private func analyzeProductCost(recipeName: String, dataService: FirebaseDataService) -> JSONObject {
        guard let recipe = dataService.recipes.first(where: { $0.name.localizedCaseInsensitiveContains(recipeName) }) else {
            return error("Recipe '\(recipeName)' not found. Available recipes: \(dataService.recipes.map(\.name).joined(separator: ", "))")
        }
        let b = ProductCostAnalyzer.analyzeProduct(recipe: recipe, inventory: dataService.inventoryItems, sales: dataService.sales, allRecipes: dataService.recipes)

        var lines: [String] = []
        lines.append("\(b.recipeName) — Cost Analysis")
        lines.append("")
        lines.append("INGREDIENTS:")
        for ing in b.ingredients {
            lines.append("  \(ing.ingredientName): \(String(format: "%.2f", ing.quantityNeeded)) \(ing.unit) @ \u{20B9}\(String(format: "%.2f", ing.costPerUnit))/\(ing.unit) = \u{20B9}\(String(format: "%.2f", ing.totalCost)) (\(String(format: "%.0f", ing.costPercentage))% of cost)")
        }
        lines.append("")
        lines.append("COST SUMMARY:")
        lines.append("  Ingredient Cost: \u{20B9}\(String(format: "%.2f", b.totalIngredientCost))")
        if b.wasteFactor > 0.01 {
            lines.append("  Waste Factor: +\u{20B9}\(String(format: "%.2f", b.wasteFactor))")
        }
        lines.append("  True Production Cost: \u{20B9}\(String(format: "%.2f", b.trueProductionCost))")
        lines.append("  Selling Price: \u{20B9}\(String(format: "%.2f", b.sellingPrice))")
        lines.append("  Profit per Serving: \u{20B9}\(String(format: "%.2f", b.profitPerServing))")
        lines.append("  Margin: \(String(format: "%.1f", b.marginPercentage))%")

        let minServings = b.ingredients.map(\.servingsAvailable).min() ?? 0
        lines.append("")
        lines.append("STOCK: Can make \(minServings) servings with current inventory")

        if !b.suggestions.isEmpty {
            lines.append("")
            lines.append("SUGGESTIONS:")
            for s in b.suggestions {
                let saving = s.potentialSaving > 0 ? " (Save \u{20B9}\(String(format: "%.0f", s.potentialSaving)))" : ""
                lines.append("  [\(s.type.rawValue)] \(s.title)\(saving): \(s.detail)")
            }
        }

        return ["analysis": .string(lines.joined(separator: "\n"))]
    }

    private func getMenuProfitability(dataService: FirebaseDataService) -> JSONObject {
        let ranking = ProductCostAnalyzer.rankMenuProfitability(recipes: dataService.recipes, inventory: dataService.inventoryItems, sales: dataService.sales)
        if ranking.isEmpty { return ["result": .string("No recipes found. Add recipes first to see profitability ranking.")] }
        let list = ranking.map { item -> String in
            "#\(item.rank) \(item.recipeName) [\(item.category)] — Cost: \u{20B9}\(String(format: "%.2f", item.totalCost)), Sell: \u{20B9}\(String(format: "%.0f", item.sellingPrice)), Margin: \(String(format: "%.0f", item.margin))%, Monthly: \(item.monthlySales) sold, \u{20B9}\(String(format: "%.0f", item.monthlyProfit)) profit"
        }.joined(separator: "\n")
        return ["profitability_ranking": .string(list)]
    }

    private func whatIfPriceChange(ingredientName: String, percent: Double, dataService: FirebaseDataService) -> JSONObject {
        guard let scenario = ProductCostAnalyzer.whatIfPriceChange(ingredientName: ingredientName, priceChangePercent: percent, recipes: dataService.recipes, inventory: dataService.inventoryItems, sales: dataService.sales) else {
            return error("Ingredient '\(ingredientName)' not found in inventory.")
        }
        var lines: [String] = []
        lines.append("WHAT-IF: \(scenario.ingredientName) price \(percent > 0 ? "increases" : "decreases") by \(String(format: "%.0f", abs(percent)))%")
        lines.append("  Current: \u{20B9}\(String(format: "%.2f", scenario.currentCost)) → New: \u{20B9}\(String(format: "%.2f", scenario.newCost))")
        if scenario.affectedRecipes.isEmpty {
            lines.append("  No recipes use this ingredient.")
        } else {
            lines.append("")
            for impact in scenario.affectedRecipes {
                lines.append("  \(impact.recipeName): Cost \u{20B9}\(String(format: "%.2f", impact.oldCost)) → \u{20B9}\(String(format: "%.2f", impact.newCost)), Margin \(String(format: "%.0f", impact.oldMargin))% → \(String(format: "%.0f", impact.newMargin))%")
                if impact.monthlyProfitImpact != 0 {
                    lines.append("    Monthly profit impact: \u{20B9}\(String(format: "%.0f", impact.monthlyProfitImpact))")
                }
            }
        }
        return ["what_if": .string(lines.joined(separator: "\n"))]
    }

    private func addRecipe(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let name = args["name"]?.stringValue,
              let categoryStr = args["category"]?.stringValue,
              let sellingPrice = args["selling_price"]?.doubleValue else {
            return error("name, category, and selling_price required")
        }
        let category = RecipeCategory(rawValue: categoryStr) ?? .other
        let servingSize = args["serving_size"]?.stringValue ?? "1 serving"
        let prepTime = args["prep_time_minutes"]?.intValue ?? 5

        var ingredients: [RecipeIngredient] = []
        if case .array(let ingArray) = args["ingredients"] {
            for ingValue in ingArray {
                if case .object(let ingDict) = ingValue {
                    let itemName = ingDict["item_name"]?.stringValue ?? ""
                    let qty = ingDict["quantity"]?.doubleValue ?? 0
                    let unit = ingDict["unit"]?.stringValue ?? "pcs"
                    let inventoryItem = findItem(itemName, in: dataService)
                    ingredients.append(RecipeIngredient(
                        inventoryItemId: inventoryItem?.id ?? "",
                        itemName: inventoryItem?.name ?? itemName,
                        quantity: qty,
                        unit: unit
                    ))
                }
            }
        }

        let recipe = Recipe(
            name: name, category: category,
            ingredients: ingredients, sellingPrice: sellingPrice,
            servingSize: servingSize, preparationTime: prepTime
        )
        do {
            try await dataService.addRecipe(recipe)
            let costBreakdown = ProductCostAnalyzer.analyzeProduct(recipe: recipe, inventory: dataService.inventoryItems, sales: dataService.sales, allRecipes: dataService.recipes)
            return ["result": .string("Recipe '\(name)' added with \(ingredients.count) ingredients. Cost: \u{20B9}\(String(format: "%.2f", costBreakdown.trueProductionCost)), Selling: \u{20B9}\(String(format: "%.0f", sellingPrice)), Margin: \(String(format: "%.0f", costBreakdown.marginPercentage))%")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    private func deleteRecipe(_ call: LocalFunctionCall, dataService: FirebaseDataService) async -> JSONObject {
        let args = call.args
        guard let recipeName = args["recipe_name"]?.stringValue else {
            return error("recipe_name required")
        }
        guard let recipe = dataService.recipes.first(where: { $0.name.localizedCaseInsensitiveContains(recipeName) }),
              let recipeId = recipe.id else {
            return error("Recipe '\(recipeName)' not found")
        }
        do {
            try await dataService.deleteRecipe(recipeId)
            return ["result": .string("Deleted recipe '\(recipe.name)'.")]
        } catch {
            return self.error(error.localizedDescription)
        }
    }

    // MARK: - Daily Briefing

    private func getDailyBriefing(dataService: FirebaseDataService) -> JSONObject {
        var sections: [String] = []

        // Low stock
        let lowItems = dataService.inventoryItems.filter { $0.isLow }
        if !lowItems.isEmpty {
            let list = lowItems.map { "\($0.name): \($0.quantity) \($0.unit)" }.joined(separator: ", ")
            sections.append("LOW STOCK (\(lowItems.count)): \(list)")
        } else {
            sections.append("STOCK: All items sufficiently stocked.")
        }

        // Today's sales
        let todaySales = dataService.todaySales
        if !todaySales.isEmpty {
            sections.append("TODAY'S SALES: \(todaySales.count) orders, \u{20B9}\(String(format: "%.0f", dataService.todayRevenue)) revenue, \u{20B9}\(String(format: "%.0f", dataService.todayProfit)) profit")
        } else {
            sections.append("TODAY'S SALES: No sales yet.")
        }

        // Pending orders
        let pending = dataService.orders.filter { $0.status == .pending || $0.status == .ordered }
        if !pending.isEmpty {
            let list = pending.map { "\($0.itemName) (\($0.status.rawValue))" }.joined(separator: ", ")
            sections.append("PENDING ORDERS (\(pending.count)): \(list)")
        }

        // Expiring items
        let expiring = dataService.inventoryItems.filter { item in
            guard let expiry = item.expiryDate else { return false }
            let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 999
            return daysLeft <= 3 && daysLeft >= 0
        }
        if !expiring.isEmpty {
            let list = expiring.map { item -> String in
                let days = Calendar.current.dateComponents([.day], from: Date(), to: item.expiryDate!).day ?? 0
                return "\(item.name) (\(days)d left)"
            }.joined(separator: ", ")
            sections.append("EXPIRING SOON: \(list)")
        }

        // Churn risk customers
        let churnRisk = dataService.customers.filter { $0.isChurnRisk }
        if !churnRisk.isEmpty {
            sections.append("CHURN RISK: \(churnRisk.count) customers haven't visited in 14+ days")
        }

        return ["briefing": .string(sections.joined(separator: "\n\n"))]
    }

    // MARK: - Helpers

    private func findItem(_ identifier: String, in dataService: FirebaseDataService) -> InventoryItem? {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = dataService.inventoryItems.first(where: {
            $0.sku?.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return match
        }
        if let match = dataService.inventoryItems.first(where: {
            $0.name.localizedCaseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return match
        }
        return dataService.inventoryItems.first(where: {
            $0.name.localizedCaseInsensitiveContains(trimmed)
        })
    }

    private func error(_ message: String) -> JSONObject {
        ["error": .string(message)]
    }

    private func preparePurchaseOrder(call: LocalFunctionCall, dataService: FirebaseDataService) -> (call: LocalFunctionCall?, detail: String?, errorMessage: String?) {
        let args = call.args

        let itemName = args["item_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !itemName.isEmpty else {
            return (nil, nil, "I need the item name to create a purchase order.")
        }

        guard let item = findItem(itemName, in: dataService) else {
            return (nil, nil, "Item '\(itemName)' not found in inventory.")
        }

        let quantityFromArgs = args["quantity"]?.intValue
        let quantityFromPrompt = extractFirstInteger(from: lastUserInput)
        let quantity = quantityFromArgs ?? quantityFromPrompt
        guard let quantity, quantity > 0 else {
            return (nil, nil, "Please specify a valid quantity to order, e.g. 'order 100 kg of coffee'.")
        }

        let supplierNameFromArgs = args["supplier_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let inferredSupplier = dataService.suppliers.first(where: { $0.id == item.supplierId })
        let supplier = dataService.suppliers.first(where: { $0.name.localizedCaseInsensitiveContains(supplierNameFromArgs) }) ?? inferredSupplier

        guard let supplier, let supplierId = supplier.id else {
            return (nil, nil, "Supplier not found for '\(item.name)'. Please mention supplier name.")
        }

        let leadDays = args["lead_days"]?.intValue ?? supplier.leadTimeInDays
        var mergedArgs = args
        mergedArgs["item_name"] = .string(item.name)
        mergedArgs["quantity"] = .number(Double(quantity))
        mergedArgs["supplier_name"] = .string(supplier.name)
        mergedArgs["lead_days"] = .number(Double(leadDays))
        mergedArgs["supplier_id"] = .string(supplierId)

        let detail = "Order \(quantity) \(item.unit) of \(item.name) from \(supplier.name)"
        return (LocalFunctionCall(name: call.name, args: mergedArgs), detail, nil)
    }

    private func extractFirstInteger(from text: String) -> Int? {
        let pattern = #"\b(\d{1,6})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let numberRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(text[numberRange])
    }

    private var toolContract: String {
        """
        IMPORTANT: item_name accepts BOTH item names ("Sugar") AND SKU codes ("sug-001", "BEV-003").

        Available tools and arguments:

        INVENTORY:
        - get_inventory_status(item_name?) — pass name or SKU
        - get_low_stock_items()
        - get_demand_forecast(item_name, days?) — pass name or SKU
        - get_waste_risks()
        - get_consumption_insights(item_name?) — pass name or SKU
        - get_item_pricing(item_name?) — pass name or SKU
        - update_stock_quantity(item_name, quantity, unit?) — pass name or SKU; quantity is amount to ADD (can be negative to subtract)
        - add_inventory_item(name, quantity, unit, reorder_level, cost_price, selling_price, supplier_name?, category?, brand?, expiry_date?)
        - update_cost_price(item_name, new_cost)
        - update_selling_price(item_name, new_selling_price)
        - update_expiry_date(item_name, expiry_date in YYYY-MM-DD)
        - delete_inventory_item(item_name)
        - log_consumption(item_name, amount)
        - log_waste(item_name, amount, reason)

        ORDERS:
        - get_orders(status?)
        - create_purchase_order(item_name, quantity, supplier_name, lead_days?)
        - update_order_status(item_name, new_status: Pending/Ordered/Delivered/Cancelled)
        - cancel_order(item_name)
        - delete_order(item_name)

        SUPPLIERS:
        - get_suppliers()
        - add_supplier(name, email, phone, address, lead_time_days, payment_terms?)
        - update_supplier(name, email?, phone?, address?, lead_time_days?, payment_terms?)
        - delete_supplier(name)

        CUSTOMERS:
        - get_customers(name?)
        - add_customer(name, email, phone, notes?)
        - update_customer(name, email?, phone?, notes?)
        - delete_customer(name)

        SALES:
        - get_sales_summary(period?: today/week/month) — use for revenue, order count, profit questions
        - get_today_sales() — use for today's sales details
        - get_top_selling_items(period?: today/week/month, limit?) — use for "best selling", "top selling", "most popular" questions
        - record_sale(item_name, quantity, payment_method: Cash/Card/UPI/Wallet, customer_name?, discount?)

        RECIPES & COST ANALYSIS:
        - get_recipes(name?) — list all recipes or filter by name
        - analyze_product_cost(recipe_name) — full cost breakdown, margin, and smart suggestions for a recipe. Use for "how much does it cost to make X", "what ingredients for X", "cost of making X"
        - get_menu_profitability() — rank all recipes by profit margin and monthly profit
        - what_if_price_change(ingredient_name, percent_change) — simulate ingredient price change impact on all recipes
        - add_recipe(name, category: Hot Beverages/Cold Beverages/Snacks/Desserts/Meals/Other, selling_price, serving_size, prep_time_minutes, ingredients: [{"item_name":"...","quantity":number,"unit":"..."}])
        - delete_recipe(recipe_name)

        GENERAL:
        - get_daily_briefing()

        REMEMBER: You MUST call a tool for ANY data question. Never say you cannot access data.
        """
    }

    private static let supportedToolNames: Set<String> = [
        // Inventory
        "get_inventory_status", "get_low_stock_items", "get_demand_forecast",
        "get_waste_risks", "get_consumption_insights", "get_item_pricing",
        "update_stock_quantity", "add_inventory_item", "update_cost_price",
        "update_selling_price", "update_expiry_date", "delete_inventory_item",
        "log_consumption", "log_waste",
        // Orders
        "get_orders", "create_purchase_order", "update_order_status",
        "cancel_order", "delete_order",
        // Suppliers
        "get_suppliers", "add_supplier", "update_supplier", "delete_supplier",
        // Customers
        "get_customers", "add_customer", "update_customer", "delete_customer",
        // Sales
        "get_sales_summary", "get_today_sales", "get_top_selling_items", "record_sale",
        // Recipes
        "get_recipes", "analyze_product_cost", "get_menu_profitability",
        "what_if_price_change", "add_recipe", "delete_recipe",
        // General
        "get_daily_briefing"
    ]

    private static let readOnlyToolNames: Set<String> = [
        "get_inventory_status", "get_low_stock_items", "get_demand_forecast",
        "get_waste_risks", "get_consumption_insights", "get_item_pricing",
        "get_orders", "get_suppliers", "get_customers",
        "get_sales_summary", "get_today_sales", "get_top_selling_items",
        "get_recipes", "analyze_product_cost", "get_menu_profitability",
        "what_if_price_change",
        "get_daily_briefing"
    ]

    private func extractNewCost(from args: JSONObject) -> Double? {
        args["new_cost"]?.doubleValue
            ?? args["new_buying_price"]?.doubleValue
            ?? args["buying_price"]?.doubleValue
            ?? args["cost_price"]?.doubleValue
    }

    private func extractNewSellingPrice(from args: JSONObject) -> Double? {
        args["new_selling_price"]?.doubleValue
            ?? args["new_price"]?.doubleValue
            ?? args["selling_price"]?.doubleValue
            ?? args["price"]?.doubleValue
    }

    private func parseDate(_ text: String) -> Date? {
        let formats = ["yyyy-MM-dd", "dd-MM-yyyy", "MM/dd/yyyy", "dd/MM/yyyy"]
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return date
            }
        }
        return nil
    }

    private func isoDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func userFacingSummary(from result: JSONObject) -> String? {
        if let text = result["result"]?.stringValue, !text.isEmpty {
            return text
        }
        if let text = result["error"]?.stringValue, !text.isEmpty {
            return "Action failed: \(text)"
        }
        return nil
    }

    private func formatReadOnlyResult(_ result: JSONObject) -> String {
        if let error = result["error"]?.stringValue {
            return error
        }
        if let text = result["result"]?.stringValue {
            return text
        }
        let textParts = result.sorted(by: { $0.key < $1.key }).compactMap { key, value -> String? in
            if case .string(let text) = value { return text }
            return nil
        }
        return textParts.isEmpty ? "No data available." : textParts.joined(separator: "\n\n")
    }

    private func extractArguments(from json: [String: Any]) -> [String: Any] {
        if let nested = json["arguments"] as? [String: Any] {
            return nested
        }
        var args = json
        args.removeValue(forKey: "type")
        args.removeValue(forKey: "name")
        args.removeValue(forKey: "tool_calls")
        return args
    }

    private func extractFirstJSONObject(from text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }
        var depth = 0
        var inString = false
        var isEscaped = false
        var end: String.Index?

        for i in text[start...].indices {
            let ch = text[i]
            if inString {
                if isEscaped {
                    isEscaped = false
                } else if ch == "\\" {
                    isEscaped = true
                } else if ch == "\"" {
                    inString = false
                }
                continue
            }
            if ch == "\"" {
                inString = true
                continue
            }
            if ch == "{" { depth += 1 }
            if ch == "}" {
                depth -= 1
                if depth == 0 {
                    end = i
                    break
                }
            }
        }
        guard let end else { return nil }
        return String(text[start...end])
    }
}

// MARK: - JSON helpers

typealias JSONObject = [String: JSONValue]

enum JSONValue {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object(JSONObject)
    case array([JSONValue])
    case null

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var intValue: Int? {
        if case .number(let value) = self { return Int(value) }
        return nil
    }

    var doubleValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    var jsonObject: Any {
        switch self {
        case .string(let value): return value
        case .number(let value): return value
        case .bool(let value): return value
        case .object(let object): return object.mapValues { $0.jsonObject }
        case .array(let values): return values.map { $0.jsonObject }
        case .null: return NSNull()
        }
    }
}

private extension Dictionary where Key == String, Value == JSONValue {
    static func from(dictionary: [String: Any]) -> [String: JSONValue] {
        dictionary.mapValues { JSONValue.from(any: $0) }
    }

    var jsonString: String {
        let jsonObject = self.mapValues { $0.jsonObject }
        guard let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return text
    }
}

private extension JSONValue {
    static func from(any value: Any) -> JSONValue {
        switch value {
        case let string as String:
            return .string(string)
        case let int as Int:
            return .number(Double(int))
        case let double as Double:
            return .number(double)
        case let bool as Bool:
            return .bool(bool)
        case let dict as [String: Any]:
            return .object(dict.mapValues { JSONValue.from(any: $0) })
        case let array as [Any]:
            return .array(array.map { JSONValue.from(any: $0) })
        default:
            return .null
        }
    }
}
