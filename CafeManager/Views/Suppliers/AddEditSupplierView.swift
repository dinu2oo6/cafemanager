import SwiftUI

struct AddEditSupplierView: View {
    @EnvironmentObject var dataService: FirebaseDataService
    @StateObject private var viewModel = SupplierViewModel()
    @Environment(\.dismiss) private var dismiss

    let supplier: Supplier?
    var isEditing: Bool { supplier?.id != nil }

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var address = ""
    @State private var leadTimeInDays = ""
    @State private var paymentTerms = "Net 30"
    @State private var onTimeDeliveryRate: Double = 80
    @State private var totalAmountOwed = ""
    @State private var validationError: String?

    let paymentOptions = ["Net 15", "Net 30", "Net 45", "Net 60", "COD", "Prepaid"]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.accent.ignoresSafeArea()

                Form {
                    // MARK: - Validation Error
                    if let error = validationError ?? viewModel.errorMessage {
                        Section {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppTheme.error)
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.error)
                            }
                        }
                    }

                    // MARK: - Contact Info
                    Section("Contact Information") {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 20)
                            TextField("Supplier Name", text: $name)
                        }
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 20)
                            TextField("Email", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                        }
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 20)
                            TextField("Phone Number", text: $phone)
                                .keyboardType(.phonePad)
                        }
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 20)
                            TextField("Address", text: $address)
                        }
                    }

                    // MARK: - Business Details
                    Section("Business Details") {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundColor(AppTheme.primary)
                                .frame(width: 20)
                            TextField("Lead Time (days)", text: $leadTimeInDays)
                                .keyboardType(.numberPad)
                        }

                        Picker("Payment Terms", selection: $paymentTerms) {
                            ForEach(paymentOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .tint(AppTheme.primary)

                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Reliability: \(Int(onTimeDeliveryRate))%")
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                HStack(spacing: 2) {
                                    ForEach(0..<5, id: \.self) { i in
                                        Image(systemName: i < Int(round(onTimeDeliveryRate / 20.0)) ? "star.fill" : "star")
                                            .font(.caption2)
                                            .foregroundColor(AppTheme.warning)
                                    }
                                }
                            }
                            Slider(value: $onTimeDeliveryRate, in: 0...100, step: 5)
                                .tint(onTimeDeliveryRate >= 80 ? AppTheme.success :
                                        onTimeDeliveryRate >= 50 ? AppTheme.warning : AppTheme.error)
                        }

                        HStack {
                            Text("\u{20B9}")
                                .foregroundColor(AppTheme.secondary)
                                .frame(width: 20)
                            TextField("Outstanding Balance", text: $totalAmountOwed)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit Supplier" : "Add Supplier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppTheme.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Update" : "Save") { saveSupplier() }
                        .foregroundColor(AppTheme.primary)
                        .bold()
                        .disabled(viewModel.isProcessing)
                }
            }
            .onAppear { populateFields() }
            .overlay {
                if viewModel.isProcessing {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    ProgressView("Saving...")
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
            }
        }
    }

    private func populateFields() {
        guard let supplier else { return }
        name = supplier.name
        email = supplier.email
        phone = supplier.phone
        address = supplier.address
        leadTimeInDays = String(supplier.leadTimeInDays)
        paymentTerms = supplier.paymentTerms
        onTimeDeliveryRate = supplier.onTimeDeliveryRate
        totalAmountOwed = supplier.totalAmountOwed > 0 ? String(format: "%.2f", supplier.totalAmountOwed) : ""
    }

    private func saveSupplier() {
        validationError = viewModel.validate(name: name, email: email, phone: phone, leadTime: leadTimeInDays)
        guard validationError == nil else { return }

        var newSupplier = supplier ?? Supplier.empty
        newSupplier.name = name.trimmingCharacters(in: .whitespaces)
        newSupplier.email = email.trimmingCharacters(in: .whitespaces)
        newSupplier.phone = phone.trimmingCharacters(in: .whitespaces)
        newSupplier.address = address.trimmingCharacters(in: .whitespaces)
        newSupplier.leadTimeInDays = Int(leadTimeInDays) ?? 3
        newSupplier.paymentTerms = paymentTerms
        newSupplier.onTimeDeliveryRate = onTimeDeliveryRate
        newSupplier.totalAmountOwed = Double(totalAmountOwed) ?? 0

        Task {
            if isEditing {
                await viewModel.updateSupplier(newSupplier, service: dataService)
            } else {
                await viewModel.addSupplier(newSupplier, service: dataService)
            }
            if viewModel.errorMessage == nil { dismiss() }
        }
    }
}
