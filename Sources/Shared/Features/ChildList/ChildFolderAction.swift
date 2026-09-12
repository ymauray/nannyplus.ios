import Foundation

/// Décisions du menu contextuel de la liste des enfants, isolées de la vue.
///
/// Ce sont elles qui empêchent une perte de données : sans elles, un dossier
/// portant des prestations ou des factures serait supprimable d'un geste. La
/// logique reproduit les `case 1` et `case 2` de `_ChildListTile`
/// (`lib/views/child_list_view.dart`).
enum ChildFolderAction {
    enum Outcome: Equatable {
        /// Refus : message d'échec à afficher, sans rien modifier.
        case refused(String)
        /// Accord sous réserve : titre et message de la boîte de confirmation.
        ///
        /// Côté Flutter, `showConfirmationDialog` passe toujours
        /// `context.t('Delete')` comme titre, y compris pour un archivage. Ce
        /// défaut n'est pas reproduit : le titre suit ici l'action réelle.
        case confirm(title: String, message: String)
    }

    static let existingServices = "Il existe des prestations pour ce dossier"

    /// Un dossier actif qui a des prestations non facturées ne peut pas être
    /// archivé. Le désarchivage, lui, n'est jamais bloqué : côté Flutter la
    /// condition commence par `!child.isArchived`.
    static func archive(child: Child, info: ServiceInfo?) -> Outcome {
        if !child.isArchived, let info, info.pendingTotal != 0 {
            return .refused(existingServices)
        }

        return child.isArchived
            ? .confirm(
                title: "Désarchiver",
                message: "Êtes-vous sûr de vouloir désarchiver ce dossier ?"
            )
            : .confirm(
                title: "Archiver",
                message: "Êtes-vous sûr de vouloir archiver ce dossier ?"
            )
    }

    /// La suppression est plus stricte que l'archivage : la moindre trace de
    /// prestation la bloque, même si plus rien n'est en attente de facturation.
    static func delete(child: Child, info: ServiceInfo?) -> Outcome {
        guard info == nil else { return .refused(existingServices) }

        return .confirm(
            title: "Supprimer",
            message: "Êtes-vous sûr de vouloir supprimer ce dossier ?"
        )
    }
}
