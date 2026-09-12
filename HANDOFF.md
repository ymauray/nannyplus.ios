# Nanny+ → portage natif iOS/macOS — Document de passation

Contexte : ce document résume ce qui a été établi dans une session Cowork précédente, pour reprendre le travail avec Claude Code (en ligne de commande) sans rien perdre. Le projet Flutter source se trouve dans le dossier voisin `../nannyplus`. Ce dossier (`nannyplus-ios`) est destiné à accueillir le nouveau projet natif.

## Contrainte du projet

Portage 1:1 vers iOS/macOS natif (Swift/SwiftUI) d'une app Flutter existante et fonctionnelle mais mal structurée. **Aucun changement visuel ni de comportement n'est souhaité par l'utilisatrice principale de l'app**, y compris les défauts d'ergonomie actuels (listes mal fichues, options peu intuitives). L'objectif est une réplique fidèle, pas une amélioration.

## Ce qu'est Nanny+

App de gestion pour nounous indépendantes (fiche App Store : https://apps.apple.com/fr/app/nanny/id1602676918, éditeur Yannick Mauray). Gratuite, aucune donnée envoyée à un serveur (100% local), iPhone/iPad/Apple Vision actuellement. Fonctionnalités : dossiers enfants (allergies, contacts, photo), suivi des heures/prestations, facturation PDF, relevés mensuels/annuels avec déductions, planning hebdo/annuel avec couleurs, congés, crédits d'heures, documents attachés, sauvegarde/restauration.

## Architecture Flutter actuelle (auditée)

- **Stockage** : SQLite unique (`childcare.db`) via `sqflite`. Schéma versionné avec 13 migrations (`lib/utils/database_util.dart`). Tables : `children`, `prices`, `services`, `invoices`, `documents`, `deductions`, `periods`, `schedule_colors`, `vacation_period`, `plannings`. **Aucun backend** — la base peut être relue telle quelle côté Swift (ex. GRDB.swift), permettant un import direct des données existantes des utilisatrices.
- **État/logique** : mélange de trois systèmes en parallèle — `flutter_bloc`/Cubit, `provider`, et `flutter_riverpod` (avec codegen), plus un dossier `provider/legacy` (migration Provider→Riverpod inachevée). Signe du "mal codé" évoqué par l'utilisateur ; la logique métier est dispersée et doit être retracée avec soin plutôt que copiée mécaniquement.
- **Modèles** : mélange de classes manuelles (`Child`, `Invoice` — `toMap`/`fromMap`/`copyWith` écrits à la main) et de classes générées par `freezed` (`Period`, `Planning`, `Deduction`, `VacationPeriod`, `ScheduleColor`).
- **PDF** : `pdf` + `printing` pour factures et plannings (à reproduire pixel pour pixel).
- **i18n** : `gettext_i18n`, FR/EN + `fr_CH`, fichiers dans `assets/i18n/`.
- **Personnalisation facture** : logo, 2 lignes de texte avec police au choix, conditions de paiement, coordonnées bancaires, adresse — stockées via `shared_preferences` (wrapper `PrefsUtil`).
- **Polices** : le projet embarque déjà les polices système Apple (SF Pro, SF Pro Display/Text) — l'identité visuelle vise déjà un rendu proche d'iOS.
- **Firebase Analytics** : un événement `app_started` envoyé au lancement — à noter, contredit la mention "aucune donnée collectée" de la fiche App Store. Décision à prendre (garder/retirer/adapter).
- **Notifications locales** : dépendance présente (`flutter_local_notifications`) mais code actuellement **désactivé/commenté** dans `main.dart` (anniversaires, factures impayées). Décision à prendre : réactiver dans la version native ou laisser de côté comme aujourd'hui.
- **Détail révélateur de la "liste bancale"** : dans la fiche enfant, les documents attachés sont stockés soit en octets dans la base soit par simple chemin fichier (deux générations de code coexistent) ; l'écran affiche une icône verte/rouge selon que le fichier est retrouvable. **À reproduire tel quel**, pas à corriger.
- **Sauvegarde/restauration** : mécanisme volontairement simple — "Backup" partage directement le fichier `childcare.db` ; "Restore" remplace ce fichier par un fichier choisi par l'utilisateur (`src/backup_restore/backup_restore_view.dart`).
- **macOS** : un dossier `macos/` existe déjà dans le projet Flutter (généré par `flutter create`) mais n'est **pas publié**. Son rôle, confirmé par l'utilisateur, est purement le confort de développement (compiler/lancer nativement sur la machine de dev sans repasser par un simulateur ou un iPhone à chaque test) — **pas un produit à adapter pour un usage desktop réel**. Objectif équivalent pour la version native : une cible macOS qui compile et tourne, sans travail d'adaptation UX dédié (avec SwiftUI, le même code partagé iOS/macOS suffit).

## Inventaire des écrans/fonctionnalités confirmés dans le code

- Liste des enfants/dossiers (tri prénom/nom configurable, archivage, création par clonage)
- Fiche enfant (photo, naissance, allergies, adresse, jusqu'à 3 téléphones avec libellés personnalisés, texte libre, crédits d'heures, documents attachés)
- Grille tarifaire (prices) réordonnable
- Saisie de prestations (tarif fixe ou horaire, calcul du total, marquage "facturé")
- Facturation (numérotation auto, génération PDF, partage/impression, marquage payé, personnalisation)
- Relevés mensuels et annuels avec déductions configurables (montant fixe ou %, périodicité)
- Planning hebdomadaire par créneaux avec couleurs par enfant + export PDF
- Planning annuel + export PDF
- Congés/vacances planifiés
- Sauvegarde/restauration
- Réglages (app, facture, tarifs, déductions)

## Stack native proposée

- **UI** : SwiftUI partagé iOS/macOS, adaptations minimales côté macOS (juste ce qu'il faut pour compiler/tourner, pas d'adaptation UX puisque cette cible reste un outil de dev)
- **Persistance** : SQLite directement (GRDB.swift recommandé) plutôt que SwiftData/CoreData, pour rester au plus près du schéma existant et permettre l'import direct des bases `childcare.db` existantes
- **Architecture** : MVVM simple, un pattern unique (contrairement aux trois qui coexistent côté Flutter), découpage écran par écran calqué sur l'existant
- **PDF** : PDFKit ou dessin direct via Core Graphics, reproduisant la mise en page actuelle

## Plan de portage (par phases)

1. Cartographie fonctionnelle fine écran par écran (champs, validations, cas limites), en s'appuyant sur des captures d'écran de la version actuelle fournies au fur et à mesure + le code Flutter déjà audité
2. Fondations natives : projet Xcode (iOS + macOS), couche SQLite lisant le schéma existant, modèles Swift équivalents
3. Portage écran par écran, ordre suggéré : liste des enfants → fiche enfant → grille tarifaire → prestations → facturation → relevés → planning/vacances → sauvegarde-restauration → réglages
4. Génération PDF (factures puis plannings), comparaison visuelle directe avec les PDF Flutter actuels
5. Migration des données réelles (vérifier qu'un `childcare.db` existant s'importe sans perte)
6. Tests d'usage croisés (utilisation en parallèle des deux versions sur les mêmes données)

## Méthode de travail convenue

Approche écran par écran : l'utilisateur fournit une capture d'écran de la version Flutter actuelle pour l'écran en cours, on la croise avec le fichier Dart correspondant (déjà localisé dans `../nannyplus/lib/...`) pour capter à la fois l'apparence exacte et la logique exacte, puis on écrit l'équivalent SwiftUI.

## Décisions prises (12 septembre 2026)

- **Firebase Analytics** : retiré. Pas de télémétrie dans la version native, ce qui aligne l'app sur la mention « aucune donnée collectée » de la fiche App Store.
- **Notifications locales** : retirées pour le moment. Elles ne fonctionnaient pas côté Flutter et étaient déjà commentées ; on ne les porte pas.
- **Scaffold** : xcodegen, `project.yml` à la racine. `NannyPlus.xcodeproj` est généré et non versionné — après toute modification de `project.yml`, relancer `xcodegen generate`.
- **Premier écran** : la liste des enfants, comme dans la version actuelle.
- **Bundle identifier** : `ch.frenchguy.nannyplus`, identique à l'app Flutter, pour un remplacement final sur l'App Store.
- **Traductions** : abandonnées. La version native est en français uniquement, toutes les chaînes en dur. Les libellés sont repris de `assets/i18n/fr.po` pour rester au mot près.
- **Fenêtre macOS** : dimensionnée comme un iPhone 16 (393 × 852 pt) pour que le rendu soit directement comparable à celui du téléphone.

## État d'avancement

**Phase 2 (fondations) faite.** Le projet compile pour iOS et macOS, et la build macOS lit la base réelle de développement (24 enfants, 1787 prestations, 266 factures) sans conversion.

- `project.yml` — deux cibles, `NannyPlus-iOS` et `NannyPlus-macOS`, partageant `Sources/Shared`. Cibles de déploiement iOS 26.0 / macOS 26.0, alignées sur les `Podfile` Flutter.
- `Sources/Shared/Data/Schema.swift` — réplique des 13 migrations. On n'utilise **pas** `DatabaseMigrator` de GRDB, qui tiendrait son journal dans une table `grdb_migrations` absente des bases sqflite : on reproduit le mécanisme `PRAGMA user_version`. Une base Flutter à jour (version 13) est ouverte sans aucune modification.
- `Sources/Shared/Data/AppDatabase.swift` — ouvre `Documents/childcare.db`, le chemin exact rendu par `getDatabasesPath` de sqflite sur Darwin (`NSDocumentDirectory`). Combiné au même bundle identifier, l'app native reprend la base existante sans import.
- `Sources/Shared/Preferences/AppPreferences.swift` — réplique de `PrefsUtil`. Les clés `shared_preferences` sont préfixées `flutter.` dans les `UserDefaults` (vérifié sur le conteneur réel) ; le préfixe est reproduit pour relire les réglages déjà enregistrés.
- `Sources/Supporting/NannyPlus-macOS.entitlements` — App Sandbox activé. Nécessaire pour que la build macOS partage le conteneur de l'app Flutter et voie donc la même base.

**Phase 3, premier écran : liste des enfants — faite.** Comparée à la capture de la version Flutter, la reproduction est fidèle : mêmes montants, mêmes dates, même bascule jour de la semaine / date complète, même total d'en-tête.

- `Sources/Shared/Design/Theme.swift` — couleurs de `constants.dart` et fontes du thème. **La police de l'app est Poppins**, pas SF Pro : le thème Flutter est bâti sur `GoogleFonts.poppins()`. Les fichiers sont repris de `assets/google_fonts/` et enregistrés à l'exécution.
- `Sources/Shared/Features/Shell/` — barre de titre, bandeau incurvé et barre d'onglets. Le bandeau reproduit le `Radius.elliptical(width / 2, height / 2)` de Flutter : les deux coins partagent la même ellipse, le bas du bandeau en est la moitié inférieure. La barre d'onglets est dessinée à la main, `TabView` plaçant ses onglets en haut de la fenêtre sur macOS.
- `Sources/Shared/Data/Repositories/ServicesRepository.swift` — `serviceInfoPerChild`, avec ses particularités conservées : le total en attente ne filtre pas les dossiers archivés alors que la dernière saisie les exclut, et un enfant qui a des factures impayées mais aucune prestation reste absent du résultat.
- Les garde-fous du menu contextuel sont reproduits : un dossier ayant des prestations en attente ne peut pas être archivé, un dossier ayant la moindre prestation ne peut pas être supprimé. Le titre de la boîte de confirmation est « Supprimer » y compris pour un archivage — c'est le comportement de la version Flutter, conservé tel quel.

**Configuration du projet Xcode** — alignée sur les conventions du projet Clepsydre (`/Volumes/EVO_PRO_1T/Development/Clepsydre`), pris comme référence maison.

- `DEVELOPMENT_TEAM: WFMP87LTRX`. Les deux cibles se signent, vérifié sur une compilation pour appareil réel.
- `developmentLanguage: fr` : sans ça, les menus système fournis par UIKit et AppKit (couper, copier, coller…) restent en anglais sur un appareil configuré en français.
- `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption: NO`, pour ne pas avoir à répondre à la question à chaque livraison TestFlight.
- Icône d'app : `Resources/Assets.xcassets`, reprise des icônes de l'app Flutter — le 1024 iOS et le jeu complet macOS dans un catalogue unique.
- Cible de tests `NannyPlusTests` et schémas partagés. `TEST_HOST` est forcé explicitement : XcodeGen le déduit du nom de la cible, qui diffère ici du nom du produit.
- Le `.xcodeproj` est committé malgré sa génération, comme sur Clepsydre, pour qu'Xcode Cloud trouve le projet et son schéma.

`Tests/SchemaTests.swift` vérifie qu'une base créée par la version native est indiscernable de celle produite par sqflite : version 13, et colonnes relevées sur une base Flutter réelle plutôt que recopiées depuis `Schema.swift`. Les quatre tests passent.

**Intégration continue** — même dispositif que Clepsydre : `ci_scripts/ci_post_clone.sh` pour Xcode Cloud et `.github/workflows/ios.yml` pour GitHub Actions.

Attention au rôle du script post-clone : chez Clepsydre il sert à régénérer le projet depuis `project-avec-montre.yml`, la variante qui embarque l'app Watch, que le Mac de développement ne peut pas compiler faute de SDK watchOS. **Cette raison n'existe pas ici** — pas d'app Watch, pas de second spec. Le script est malgré tout utile pour une autre raison : le `.xcodeproj` étant committé, il peut dériver de `project.yml` si quelqu'un modifie le spec sans relancer `xcodegen`. Le régénérer au clonage garantit qu'Xcode Cloud compile bien ce que décrit `project.yml`.

Le workflow GitHub est réduit en conséquence : pas de job « module partagé » (il n'y a pas d'équivalent de `ClepsydreCore`) ni de job « bundle complet ». Restent la compilation et les tests iOS, plus un job de compilation macOS pour que le code partagé ne casse pas de ce côté. Les deux commandes ont été exécutées localement à l'identique et passent.

**Deux défauts d'affichage corrigés après essai sur simulateur iPhone**, tous deux invisibles sur la cible macOS :

- Un vide de la hauteur de l'encoche séparait la barre de titre du bandeau. La barre cumulait une marge haute égale à la zone sûre **et** un `ignoresSafeArea` : le fond remontait mais la hauteur restait réservée. Seul le fond déborde désormais sous la barre d'état, la vue gardant ses 56 points sous la zone sûre.
- Un liseré sombre marquait la jonction entre la barre de titre et le bandeau : l'ombre du bandeau, projetée sur tout son pourtour, débordait vers le haut. La barre de titre est maintenant peinte par-dessus (`zIndex`), ce que fait Flutter, où la `SliverAppBar` recouvre le bandeau.

Leçon de méthode : la cible macOS ne suffit pas à valider un écran. Elle n'a ni encoche ni zone sûre, et masque donc toute une catégorie de défauts. Chaque écran porté doit être vu sur simulateur iPhone avant d'être considéré comme terminé.

**Tiroir de navigation porté** (`Sources/Shared/Features/Shell/MainDrawer.swift`). SwiftUI n'a pas d'équivalent du `Drawer` de Material : le panneau de 304 points, le voile et l'animation sont dessinés à la main dans `MainTabView`.

Le portage a demandé de mesurer la capture de référence au pixel plutôt que de suivre le code Dart, et c'est instructif pour la suite :

- **Le `fontWeight: FontWeight.bold` du Dart ne s'applique pas.** Les libellés du tiroir se mesurent en graisse 500 (Medium), pas 700. `google_fonts` résout une famille par graisse : forcer w700 sur une famille qui ne contient que la w500 retombe sur cette dernière. Sur l'écran liste en revanche, le gras fonctionne, parce que le style vient de `titleMedium` que `GoogleFonts.poppins` a résolu en gras à la construction du thème. **Leçon : sur cette app, lire le style rendu, pas le style écrit.**
- **Styles réels du tiroir** : titres en `bodyLarge` de la typographie Material 2014, soit 14 points en graisse 500 ; ligne de version en `bodyMedium`, 14 points en graisse 400. Vérifié sur trois chaînes de longueurs différentes, à 0,3 % près.
- **La capture de référence a été prise avec une taille de texte système réduite** (environ 0,93). Les polices suivent désormais le réglage système, comme Flutter : `Font.custom(_:size:)` et non `fixedSize:`. Pour comparer une capture à la référence, aligner le simulateur avec `xcrun simctl ui <appareil> content_size medium`.
- À la taille de texte par défaut, « Réinitialiser les messages d'aide » passe sur deux lignes : 226 points de texte pour 216 disponibles dans un tiroir de largeur fixe. La version Flutter fait de même dans les mêmes conditions — déduction géométrique, la police étant maintenant identique, non vérifiée sur l'app Flutter elle-même.

Seul « Réinitialiser les messages d'aide » est fonctionnel (suppression des clés `flutter.help_*`), ainsi que « Réinitialiser la base de données », réservé aux compilations de debug comme le `kDebugMode` de Flutter. **Attention** : sur la cible macOS, cet élément supprime la base réelle, le conteneur étant partagé avec l'app Flutter. Le risque existe déjà à l'identique côté Flutter.

**Outillage d'essai** : `cliclick` est installé. La fenêtre du simulateur expose l'écran de l'appareil comme un groupe d'accessibilité en 1:1, ce qui permet de convertir points appareil → écran sans deviner de facteur de zoom (`position of group 1` de la fenêtre du processus Simulator). Il faut activer la fenêtre avant de cliquer, sinon le clic est absorbé.

### Reste à faire sur ces fondations

- `insertSampleData` (jeu de démonstration inséré à la première ouverture : tarifs, enfants, prestations, facture, réglages de facturation et logo) n'est pas porté. À traiter avec l'onboarding.
- Sur l'écran liste : le formulaire enfant (création et duplication), la navigation vers la fiche enfant, et la boîte de dialogue d'accueil ne sont pas portés — les boutons correspondants sont en place mais sans action.
- Dans le tiroir : « Sauvegarder / Restaurer » et « Politique de confidentialité » ouvrent des écrans non portés ; les entrées ferment simplement le tiroir.
- Les garde-fous d'archivage et de suppression sont couverts par `Tests/ChildFolderActionTests.swift`. La décision a été extraite de la vue dans `ChildFolderAction`, précisément pour pouvoir la vérifier : ce sont eux qui empêchent de supprimer un dossier portant des prestations et des factures. Le parcours complet (menu, boîte de confirmation, bandeau) n'a en revanche jamais été cliqué — il n'y a pas d'outil de clic sur simulateur installé sur la machine.
- Sur macOS, la barre de défilement reste visible là où Flutter n'en montrait pas ; c'est le réglage système du Mac, sans effet sur iOS.

## À revoir une fois le portage initial terminé

Points volontairement laissés de côté pendant le portage, à traiter après.

- **Cibles de déploiement iOS 26.0 / macOS 26.0** — reprises des `Podfile` Flutter. C'est restrictif pour une app grand public : à confirmer, et à abaisser si la valeur actuelle vient d'une mise à jour d'Xcode plutôt que d'un choix délibéré. Une ligne à changer dans `project.yml`.
- **Nettoyage de la base de données** — il y a du ménage à faire dans les données existantes. Yannick doit d'abord étudier ce qui est concerné ; à ne pas entreprendre avant cette analyse, et surtout pas pendant le portage, pour que les deux versions restent comparables sur des données identiques.

## Prochaine étape

Écran suivant dans l'ordre convenu : la fiche enfant. Capture d'écran de la version Flutter à fournir.
