import Foundation

/// Réplique de `lib/data/model/service_info.dart`.
struct ServiceInfo: Hashable, Sendable {
    var pendingTotal: Double
    var lastEntry: Date?
    var pendingInvoice: Double
}
