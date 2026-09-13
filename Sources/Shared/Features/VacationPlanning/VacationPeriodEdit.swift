import Foundation

/// Les règles de saisie du planning des congés, sorties de la vue pour être
/// vérifiables — comme `ChildFolderAction` pour les garde-fous de la liste des
/// dossiers.
///
/// Elles viennent de `vacation_planning_view_state_provider.dart`.
enum VacationPeriodEdit {
    /// Déplacer le début au-delà de la fin pousse la fin avec lui.
    static func movingStart(of period: VacationPeriod, to start: String) -> VacationPeriod {
        var moved = period
        moved.start = start

        if let end = moved.end, end < start { moved.end = start }

        return moved
    }

    /// Poser une fin avant le début tire le début avec elle. `nil` referme la
    /// période sur une journée isolée.
    static func settingEnd(of period: VacationPeriod, to end: String?) -> VacationPeriod {
        var changed = period
        changed.end = end

        if let end, changed.start > end { changed.start = end }

        return changed
    }

    /// Par date de début, puis par date de fin — une journée isolée passant
    /// avant une période qui commence le même jour.
    static func sorted(_ periods: [VacationPeriod]) -> [VacationPeriod] {
        periods.sorted { first, second in
            if first.start != second.start { return first.start < second.start }

            switch (first.end, second.end) {
            case (nil, nil): return false
            case (nil, _): return true
            case (_, nil): return false
            case let (firstEnd?, secondEnd?): return firstEnd < secondEnd
            }
        }
    }

    /// La date que retient le bouton « + » : le 1er janvier de l'année tant que
    /// la liste est vide, sinon la plus tardive des dates connues — **fins
    /// comprises**, si bien qu'une période débordant sur l'année suivante fait
    /// créer le congé dans cette année-là, où il disparaît aussitôt de la liste.
    static func lastDay(in periods: [VacationPeriod], year: Int) -> String {
        periods
            .flatMap { [$0.start, $0.end].compactMap { $0 } }
            .reduce("\(year)-01-01") { max($0, $1) }
    }
}
