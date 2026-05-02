import SwiftUI

struct AddEditCustomerView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @Environment(\.dismiss) private var dismiss

    let customer: Customer?

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var totalSpent: String = ""
    @State private var visitCount: String = ""
    @State private var notes: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    private var isEditing: Bool { customer != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.accent.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.sectionSpacing) {
                        if isEditing, let customer {
                            loyaltyCard(customer)
                        }
                        formSection
                        if isEditing {
                            statsSection
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle(isEditing ? "Edit Customer" : "Add Customer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        Task { await save() }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .onAppear { loadCustomer() }
            .alert("Error", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Loyalty Card

    private func loyaltyCard(_ customer: Customer) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(tierColor(customer.loyaltyTier).opacity(0.2))
                    .frame(width: 56, height: 56)
                Image(systemName: customer.loyaltyTier.icon)
                    .font(.title2)
                    .foregroundColor(tierColor(customer.loyaltyTier))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(customer.loyaltyTier.rawValue + " Member")
                    .font(.headline)
                    .foregroundColor(AppTheme.textPrimary)
                if customer.loyaltyTier.discountPercentage > 0 {
                    Text("\(Int(customer.loyaltyTier.discountPercentage))% loyalty discount")
                        .font(.caption)
                        .foregroundColor(AppTheme.success)
                }
                if customer.isChurnRisk {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                        Text("Churn risk — \(customer.daysSinceLastVisit ?? 0) days since last visit")
                            .font(.caption)
                    }
                    .foregroundColor(AppTheme.error)
                }
            }
            Spacer()
        }
        .padding()
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Customer Details")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            TextField("Name *", text: $name)
                .textFieldStyle(.roundedBorder)
            TextField("Email", text: $email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            TextField("Phone", text: $phone)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.phonePad)
            HStack(spacing: 12) {
                VStack(alignment: .leading) {
                    Text("Total Spent (₹)")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondary)
                    TextField("0", text: $totalSpent)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.decimalPad)
                }
                VStack(alignment: .leading) {
                    Text("Visit Count")
                        .font(.caption)
                        .foregroundColor(AppTheme.secondary)
                    TextField("0", text: $visitCount)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                }
            }
            TextField("Notes", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Customer Insights")
                .font(.headline)
                .foregroundColor(AppTheme.textPrimary)

            if let customer {
                HStack(spacing: 16) {
                    insightPill(label: "Avg Order", value: currencyString(customer.averageOrderValue))
                    insightPill(label: "Visits", value: "\(customer.visitCount)")
                    insightPill(label: "Lifetime", value: currencyString(customer.totalSpent))
                }

                if !customer.favoriteItems.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Favorite Items")
                            .font(.caption)
                            .foregroundColor(AppTheme.secondary)
                        FlowLayout(spacing: 6) {
                            ForEach(customer.favoriteItems, id: \.self) { item in
                                Text(item)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.primary.opacity(0.1))
                                    .foregroundColor(AppTheme.primary)
                                    .cornerRadius(12)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(AppTheme.cornerRadius)
    }

    private func insightPill(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(AppTheme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppTheme.accent)
        .cornerRadius(8)
    }

    // MARK: - Actions

    private func loadCustomer() {
        guard let customer else { return }
        name = customer.name
        email = customer.email
        phone = customer.phone
        totalSpent = String(format: "%.0f", customer.totalSpent)
        visitCount = "\(customer.visitCount)"
        notes = customer.notes ?? ""
    }

    private func save() async {
        isSaving = true
        var c = customer ?? Customer.empty
        c.name = name
        c.email = email
        c.phone = phone
        c.totalSpent = Double(totalSpent) ?? 0
        c.visitCount = Int(visitCount) ?? 0
        c.notes = notes.isEmpty ? nil : notes
        c.lastVisitDate = c.lastVisitDate ?? (c.visitCount > 0 ? Date() : nil)

        do {
            if isEditing {
                try await dataService.updateCustomer(c)
            } else {
                try await dataService.addCustomer(c)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    private func tierColor(_ tier: LoyaltyTier) -> Color {
        switch tier {
        case .gold: return Color(red: 1, green: 0.84, blue: 0)
        case .silver: return Color.gray
        case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
        }
    }

    private func currencyString(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹0"
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(in: proposal.width ?? 0, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(in: bounds.width, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(in width: CGFloat, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var maxHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += maxHeight + spacing
                maxHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            maxHeight = max(maxHeight, size.height)
            x += size.width + spacing
            totalHeight = y + maxHeight
        }

        return (CGSize(width: width, height: totalHeight), positions)
    }
}
