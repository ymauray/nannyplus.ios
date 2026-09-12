# Nanny+ natif — Spécification du portage

Ce que l'on construit, et pourquoi. L'état d'implémentation est dans
[AVANCEMENT.md](AVANCEMENT.md).

Le projet Flutter source est dans le dossier voisin `../nannyplus`.

> **Référence de portage : `main`**, qui reflète désormais la production
> (1.26.4, build 195) depuis la fusion de la PR #8.

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

## Un écart entre `main` et la production, résolu

Pendant un temps, la version en production a été compilée depuis la branche
`yearly_statements_improvement`, jamais fusionnée. `main` accusait donc deux
commits de retard sur ce que voyaient les utilisatrices. La branche a depuis été
fusionnée (PR #8) et `main` est de nouveau la bonne référence.

Ce que la branche apportait, à connaître au moment de porter le relevé annuel :

- `86b53ae` *fix: labels on yearly statements* — dans le PDF du relevé annuel,
  deux mentions ajoutées sous le tableau (« Les montants dus figurent sur les
  factures correspondantes. » et « Les factures impayées sont indiquées avec un
  montant de 0.00 ») et deux en-têtes de colonne précisés : « Date » devient
  « Date de facture », « Montant » devient « Montant payé ».
- `5647d6f` — passage du `pubspec.yaml` en 1.26.4.

Les écrans déjà portés — liste des enfants, tiroir, politique de confidentialité —
n'étaient pas concernés.

**La leçon vaut pour la suite** : avant de porter un écran, vérifier que la
branche lue est bien celle qui tourne en production. Le dépôt Flutter a déjà
livré depuis une branche non fusionnée une fois.

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

Trois règles tirées des premiers écrans portés, chacune née d'une erreur réelle
— le détail des cas est dans [AVANCEMENT.md](AVANCEMENT.md).

- **Lire le style rendu, pas le style écrit.** Le code Dart peut demander une
  graisse que Flutter n'applique pas. En cas de doute, mesurer la capture au
  pixel plutôt que se fier à la source.
- **Valider chaque écran sur simulateur iPhone.** La cible macOS n'a ni encoche
  ni zone sûre et masque toute une catégorie de défauts de mise en page.
- **Aligner la taille de texte avant de comparer.** Les captures de référence
  peuvent être prises avec un réglage système réduit :
  `xcrun simctl ui <appareil> content_size medium`.

## Conventions Git

Consignes de Yannick, à appliquer sans exception.

1. **Ne jamais committer sans y être invité.**
2. **Ne pas suggérer de committer** après une modification — Yannick décide du moment.
3. **S'identifier systématiquement comme co-auteur** du commit.
4. **Messages de commit en français**, conformes à la norme *conventional commits* : `type(portée): description`, par exemple `feat(liste): ...`, `fix(tiroir): ...`.
5. **Ne jamais pousser sur le dépôt distant sans y être invité.**
6. **Ne pas suggérer de pousser** après un commit — Yannick décide du moment.

En pratique : terminer une tâche en décrivant ce qui a changé, sans mention de commit ni de push. N'aborder Git que sur demande, ou pour signaler un fait qui concerne directement Yannick — un conflit, un fichier indûment versionné.

## Décisions prises (12 septembre 2026)

- **Firebase Analytics** : retiré. Pas de télémétrie dans la version native, ce qui aligne l'app sur la mention « aucune donnée collectée » de la fiche App Store.
- **Notifications locales** : retirées pour le moment. Elles ne fonctionnaient pas côté Flutter et étaient déjà commentées ; on ne les porte pas.
- **Scaffold** : xcodegen, `project.yml` à la racine, source de vérité. Après toute modification de `project.yml`, relancer `xcodegen generate`. Le `NannyPlus.xcodeproj` produit est malgré tout versionné, comme sur Clepsydre, pour qu'Xcode Cloud trouve le projet et son schéma partagé.
- **Premier écran** : la liste des enfants, comme dans la version actuelle.
- **Bundle identifier** : `ch.frenchguy.nannyplus`, identique à l'app Flutter, pour un remplacement final sur l'App Store.
- **Traductions** : abandonnées. La version native est en français uniquement, toutes les chaînes en dur. Les libellés sont repris de `assets/i18n/fr.po` pour rester au mot près.
- **Ordre des boutons des boîtes de confirmation** : on garde l'ordre natif de SwiftUI, l'annulation à gauche et la confirmation à droite. Flutter affichait l'inverse (« Oui » puis « Non »), plaçant l'action confirmante sous le pouce. Le coût assumé est transitoire : une utilisatrice habituée à l'ancienne disposition peut se tromper les premières fois.
- **Fenêtre macOS** : dimensionnée comme un iPhone 16 (393 × 852 pt) pour que le rendu soit directement comparable à celui du téléphone.
- **Numérotation de version** : alignée sur la production, soit 1.26.4.

  *Côté Flutter*, la version vient du `pubspec.yaml`. `flutter build` la recopie dans `ios/Flutter/Generated.xcconfig` sous `FLUTTER_BUILD_NAME` et `FLUTTER_BUILD_NUMBER`, et l'`Info.plist` du projet iOS y renvoie par `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)`. Les `MARKETING_VERSION = 1.0.0` et `CURRENT_PROJECT_VERSION = 6` que porte encore le `project.pbxproj` sont des vestiges inutilisés. Le `+9999` du `pubspec` est un repère local : le vrai numéro de build est posé à la livraison par **Codemagic**, dont le workflow est configuré dans l'interface web et non dans le dépôt — d'où l'absence de tout fichier de CI côté Flutter, et l'écart entre le `pubspec` local (1.26.3) et la production (1.26.4, build 195).

  **Changement de CI, et risque de continuité.** Le projet natif passe à Xcode Cloud, pas à Codemagic. Xcode Cloud tient son propre compteur de builds, qui démarre à 1 et ignore tout des 195 builds déjà livrés par Codemagic. Si le premier téléversement sort un numéro inférieur ou égal à 195 pour la version 1.26.4, App Store Connect le refusera. À régler avant la première livraison, soit en fixant le numéro de départ du workflow Xcode Cloud au-dessus de 195, soit en gardant la main sur `CURRENT_PROJECT_VERSION` dans `project.yml`.

  *Côté natif*, le chemin est plus court : `project.yml` porte `MARKETING_VERSION` et `CURRENT_PROJECT_VERSION`, XcodeGen les écrit dans le projet, et `GENERATE_INFOPLIST_FILE` les reporte dans `CFBundleShortVersionString` et `CFBundleVersion`. `project.yml` joue donc le rôle du `pubspec.yaml`, et c'est le seul endroit à modifier. L'app relit ces valeurs à l'exécution via `Bundle.main`, comme `package_info_plus` le faisait. Le `pubspec.yaml` du projet Flutter affiche 1.26.4+9999 : le `+9999` est un repère local, le numéro de build réel étant posé à la livraison par la CI, d'où le 195 en production. Le projet natif part donc de `MARKETING_VERSION: 1.26.4` et `CURRENT_PROJECT_VERSION: 196`. **Le build doit être strictement supérieur à 195** : App Store Connect refuse un numéro déjà téléversé pour la même version, et livrer 195 ferait échouer l'envoi sur TestFlight.
