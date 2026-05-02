import Foundation

@MainActor
class CustomerViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var selectedTierFilter: LoyaltyTier?
    @Published var showChurnRiskOnly = false
    @Published var errorMessage: String?

    func filteredCustomers(from customers: [Customer]) -> [Customer] {
        var result = customers
        if let tier = selectedTierFilter {
            result = result.filter { $0.loyaltyTier == tier }
        }
        if showChurnRiskOnly {
            result = result.filter { $0.isChurnRisk }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.phone.localizedCaseInsensitiveContains(searchText)
                || $0.email.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result.sorted { $0.totalSpent > $1.totalSpent }
    }

    func addCustomer(_ customer: Customer, dataService: FirebaseDataService) async {
        do {
            try await dataService.addCustomer(customer)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateCustomer(_ customer: Customer, dataService: FirebaseDataService) async {
        do {
            try await dataService.updateCustomer(customer)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCustomer(_ customerId: String, dataService: FirebaseDataService) async {
        do {
            try await dataService.deleteCustomer(customerId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func customerStats(from customers: [Customer]) -> CustomerStats {
        let total = customers.count
        let gold = customers.filter { $0.loyaltyTier == .gold }.count
        let silver = customers.filter { $0.loyaltyTier == .silver }.count
        let churnRisk = customers.filter { $0.isChurnRisk }.count
        let totalRevenue = customers.reduce(0) { $0 + $1.totalSpent }
        let avgValue = total > 0 ? totalRevenue / Double(total) : 0

        return CustomerStats(
            totalCustomers: total,
            goldMembers: gold,
            silverMembers: silver,
            churnRiskCount: churnRisk,
            totalLifetimeRevenue: totalRevenue,
            averageCustomerValue: avgValue
        )
    }
}

struct CustomerStats {
    let totalCustomers: Int
    let goldMembers: Int
    let silverMembers: Int
    let churnRiskCount: Int
    let totalLifetimeRevenue: Double
    let averageCustomerValue: Double
}
