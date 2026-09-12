import Foundation
import Testing

@testable import NannyPlus

/// Ces garde-fous sont la seule chose qui empêche de supprimer un dossier
/// portant des prestations et des factures. Ils sont vérifiés ici plutôt que
/// par un essai manuel, pour que la CI les protège.
struct ChildFolderActionTests {
    private let active = Child(id: 1, firstName: "Maé", lastName: "Burri")
    private let archived = Child(id: 2, firstName: "Zoé", lastName: "Mauray", archived: 1)

    private func info(pendingTotal: Double) -> ServiceInfo {
        ServiceInfo(pendingTotal: pendingTotal, lastEntry: nil, pendingInvoice: 0)
    }

    // MARK: Archivage

    @Test("Un dossier actif avec des prestations en attente ne peut pas être archivé")
    func archiveBlockedByPendingServices() {
        let outcome = ChildFolderAction.archive(child: active, info: info(pendingTotal: 1281))

        #expect(outcome == .refused(ChildFolderAction.existingServices))
    }

    @Test("Un dossier actif dont tout est facturé peut être archivé")
    func archiveAllowedWhenNothingPending() {
        let outcome = ChildFolderAction.archive(child: active, info: info(pendingTotal: 0))

        #expect(outcome == .confirm("Êtes-vous sûr de vouloir archiver ce dossier ?"))
    }

    @Test("Un dossier sans aucune prestation peut être archivé")
    func archiveAllowedWithoutServices() {
        let outcome = ChildFolderAction.archive(child: active, info: nil)

        #expect(outcome == .confirm("Êtes-vous sûr de vouloir archiver ce dossier ?"))
    }

    @Test("Le désarchivage n'est jamais bloqué, même avec des prestations en attente")
    func unarchiveIsNeverBlocked() {
        let outcome = ChildFolderAction.archive(child: archived, info: info(pendingTotal: 1281))

        #expect(outcome == .confirm("Êtes-vous sûr de vouloir désarchiver ce dossier ?"))
    }

    // MARK: Suppression

    @Test("La suppression est bloquée dès qu'il existe une prestation, même soldée")
    func deleteBlockedEvenWhenNothingPending() {
        // Cas réel observé dans la base : un dossier dont tout est facturé garde
        // un historique, et reste donc non supprimable alors qu'il est
        // archivable. C'est la différence entre les deux garde-fous.
        let outcome = ChildFolderAction.delete(child: active, info: info(pendingTotal: 0))

        #expect(outcome == .refused(ChildFolderAction.existingServices))
    }

    @Test("Un dossier vierge de toute prestation peut être supprimé")
    func deleteAllowedWithoutServices() {
        let outcome = ChildFolderAction.delete(child: active, info: nil)

        #expect(outcome == .confirm("Êtes-vous sûr de vouloir supprimer ce dossier ?"))
    }
}
