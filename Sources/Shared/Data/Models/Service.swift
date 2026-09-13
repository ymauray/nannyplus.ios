import Foundation
import GRDB

/// Réplique de `lib/data/model/service.dart`.
///
/// Une prestation d'un jour : un tarif, et selon qu'il est fixe ou horaire, un
/// montant tel quel ou une durée multipliée par le taux. Le libellé et le
/// montant du tarif sont **recopiés dans la ligne** au moment de la saisie, si
/// bien qu'une prestation ancienne garde le tarif d'alors.
struct Service: Identifiable, Hashable, Sendable {
    var id: Int64?
    var childId: Int64
    /// `yyyy-MM-dd`, comparable tel quel.
    var date: String
    var priceId: Int64
    var priceLabel: String?
    var priceAmount: Double?
    /// 0 ou 1 : la base stocke un entier, pas un booléen.
    var isFixedPrice: Int?
    var hours: Int?
    var minutes: Int?
    var total: Double
    var invoiced: Int = 0
    var invoiceId: Int64?
}

extension Service {
    var isHourly: Bool { isFixedPrice == 0 }

    /// « 4h30 x 8.00 » pour un tarif horaire, rien pour un tarif fixe.
    var priceDetail: String {
        guard isHourly else { return "" }

        let hours = hours ?? 0
        let minutes = String(format: "%02d", minutes ?? 0)

        return "\(hours)h\(minutes) x \((priceAmount ?? 0).twoDecimals)"
    }

    /// Le libellé du formulaire de saisie : « Tarif fixe de 5.00 », ou
    /// « Tarif horaire de 8.00 x 2h30 ».
    var formDetail: String {
        let amount = (priceAmount ?? 0).twoDecimals

        guard isHourly else { return "Tarif fixe de \(amount)" }

        return "Tarif horaire de \(amount) x \(hours ?? 0)h\(String(format: "%02d", minutes ?? 0))"
    }
}

extension Service: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "services"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// Les prestations d'une même journée, telles que la carte les affiche.
struct ServiceDay: Identifiable, Hashable, Sendable {
    /// `yyyy-MM-dd` : la date fait l'identité du groupe.
    var id: String { date }

    let date: String
    let services: [Service]

    var total: Double { services.reduce(0) { $0 + $1.total } }
}
