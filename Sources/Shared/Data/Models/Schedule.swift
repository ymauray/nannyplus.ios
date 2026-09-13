import Foundation
import GRDB

/// Réplique de `lib/data/model/period.dart`.
///
/// Un créneau de garde hebdomadaire : un enfant, un jour de la semaine en
/// anglais et en minuscules (`monday`…), une heure de début et une de fin.
struct Period: Identifiable, Hashable, Sendable {
    var id: Int64?
    var childId: Int64
    var day: String
    var hourFrom: Int
    var minuteFrom: Int
    var hourTo: Int
    var minuteTo: Int
    var sortOrder: Int = 0
    /// Colonne ajoutée par une migration tardive, que le planning hebdomadaire
    /// ignore : `readPeriods` lit toutes les lignes sans filtrer.
    var planningId: Int64?
}

extension Period {
    var startMinute: Int { hourFrom * 60 + minuteFrom }

    var endMinute: Int { hourTo * 60 + minuteTo }

    /// Un créneau appartient au matin ou à l'après-midi selon sa **seule heure
    /// de début** : une garde de 8:00 à 17:45 compte pour le matin. C'est ainsi
    /// que le planning annuel classe ses demi-cases.
    var isMorning: Bool { hourFrom < 12 }

    /// Le créneau couvre-t-il le quart d'heure commençant à `hour:minute` ?
    /// Début inclus, fin exclue, comme côté Flutter.
    func covers(hour: Int, minute: Int) -> Bool {
        let slot = hour * 60 + minute

        return startMinute <= slot && slot < endMinute
    }
}

extension Period: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "periods"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// Réplique de `lib/data/model/schedule_color.dart`.
///
/// `color` est la valeur entière d'une `Color` de Flutter, soit un ARGB sur 32
/// bits.
struct ScheduleColor: Identifiable, Hashable, Sendable {
    var id: Int64?
    var childId: Int64
    var color: Int64
}

extension ScheduleColor: Codable, FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "schedule_colors"

    mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

/// Réplique de `lib/data/model/schedule.dart`, assemblée par
/// `weeklyScheduleProvider`.
struct Schedule: Sendable {
    /// Les enfants ayant au moins un créneau, dans l'ordre de la liste des
    /// dossiers — donc soumis aux réglages de tri, et sans les archivés.
    var childIds: [Int64] = []
    var periods: [Period] = []
    var scheduleColors: [ScheduleColor] = []
    /// Initiales par enfant, tous dossiers confondus.
    var childrenNames: [Int64: String] = [:]

    static let empty = Schedule()

    func periodsByDay(_ day: String) -> [Period] {
        periods.filter { $0.day == day.lowercased() }
    }

    /// Côté Flutter, `.first` sur une couleur absente lèverait une exception.
    /// On retombe ici sur le violet, celui que `readColor` attribue d'office à
    /// un enfant qui n'a pas encore de couleur.
    func color(for childId: Int64) -> Int64 {
        scheduleColors.first { $0.childId == childId }?.color ?? 0xFF9C_27B0
    }
}
