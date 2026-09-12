import Foundation

/// Réplique de `ChildListController` (`lib/provider/legacy/child_list_provider.dart`)
/// et de l'état `ChildListLoaded`.
@MainActor
@Observable
final class ChildListViewModel {
    struct Totals {
        var pendingTotal: Double
        var pendingInvoice: Double
    }

    private(set) var children: [Child] = []
    private(set) var servicesInfo: [Int64: ServiceInfo] = [:]
    private(set) var overdueInvoices: Set<Int64> = []
    private(set) var totals: Totals?
    private(set) var showArchived = false
    private(set) var errorMessage: String?

    private let children_ = ChildrenRepository()
    private let services = ServicesRepository()
    private let invoices = InvoicesRepository()

    func load() async {
        do {
            let children = try await children_.childList(showArchived: showArchived)
            let servicesInfo = try await services.serviceInfoPerChild()
            let overdue = try await invoices.childrenWithOverdueInvoices()

            self.children = children
            self.servicesInfo = servicesInfo
            self.overdueInvoices = overdue
            self.totals = Totals(
                pendingTotal: servicesInfo.values.reduce(0) { $0 + $1.pendingTotal },
                pendingInvoice: servicesInfo.values.reduce(0) { $0 + $1.pendingInvoice }
            )
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func toggleShowArchived() async {
        showArchived.toggle()
        await load()
    }

    func setArchived(_ archived: Bool, for child: Child) async {
        var updated = child
        updated.archived = archived ? 1 : 0

        do {
            try await children_.update(updated)
            await load()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    func delete(_ child: Child) async {
        do {
            try await children_.delete(child)
            await load()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    /// Élément de tiroir réservé aux compilations de debug : supprime la base
    /// et les préférences, puis recharge.
    func resetDatabase() async {
        do {
            try await AppDatabase.shared.delete()
            AppPreferences.shared.clear()
            await load()
        } catch {
            errorMessage = String(describing: error)
        }
    }

    // MARK: Dérivés par enfant

    func info(for child: Child) -> ServiceInfo? {
        child.id.flatMap { servicesInfo[$0] }
    }

    func hasOverdueInvoice(_ child: Child) -> Bool {
        child.id.map { overdueInvoices.contains($0) } ?? false
    }
}
