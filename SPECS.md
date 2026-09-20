# Nanny+ natif — Spécification du portage

Ce que l'on construit, et pourquoi. L'état d'implémentation est dans
[AVANCEMENT.md](AVANCEMENT.md).

Le projet Flutter source est dans le dossier voisin `../nannyplus`.

> **Référence de portage : la branche `main` du dépôt Flutter voisin**, qui
> reflète la production (1.26.4, build 195) depuis la fusion de sa PR #8. À ne
> pas confondre avec le `main` du présent dépôt.

## Contrainte du projet

Portage vers iOS natif (Swift/SwiftUI) d'une app Flutter existante et fonctionnelle mais mal structurée. **Aucun changement visuel ni de comportement n'est souhaité par l'utilisatrice principale de l'app**, y compris les défauts d'ergonomie actuels (listes mal fichues, options peu intuitives). L'objectif est une réplique fidèle, pas une amélioration.

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
- **macOS** : un dossier `macos/` existe dans le projet Flutter, non publié, qui sert uniquement à compiler et lancer l'app sur la machine de développement. La version native n'a **pas** d'équivalent : la cible macOS a été essayée puis retirée. Ce build Flutter macOS reste en revanche très utile pour produire les captures de référence sans solliciter Yannick.

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

- **UI** : SwiftUI, iOS uniquement
- **Persistance** : SQLite directement (GRDB.swift recommandé) plutôt que SwiftData/CoreData, pour rester au plus près du schéma existant et permettre l'import direct des bases `childcare.db` existantes
- **Architecture** : MVVM simple, un pattern unique (contrairement aux trois qui coexistent côté Flutter), découpage écran par écran calqué sur l'existant
- **PDF** : PDFKit ou dessin direct via Core Graphics, reproduisant la mise en page actuelle

## Plan de portage (par phases)

1. Cartographie fonctionnelle fine écran par écran (champs, validations, cas limites), en s'appuyant sur des captures d'écran de la version actuelle fournies au fur et à mesure + le code Flutter déjà audité
2. Fondations natives : projet Xcode, couche SQLite lisant le schéma existant, modèles Swift équivalents
3. Portage écran par écran, ordre suggéré : liste des enfants → fiche enfant → grille tarifaire → prestations → facturation → relevés → planning/vacances → sauvegarde-restauration → réglages
4. Génération PDF (factures puis plannings), comparaison visuelle directe avec les PDF Flutter actuels
5. Migration des données réelles (vérifier qu'un `childcare.db` existant s'importe sans perte)
6. Tests d'usage croisés (utilisation en parallèle des deux versions sur les mêmes données)

## Méthode de travail convenue

Approche écran par écran : l'utilisateur fournit une capture d'écran de la version Flutter actuelle pour l'écran en cours, on la croise avec le fichier Dart correspondant (déjà localisé dans `../nannyplus/lib/...`) pour capter à la fois l'apparence exacte et la logique exacte, puis on écrit l'équivalent SwiftUI.

**Les captures de référence viennent toujours du téléphone de Yannick.** C'est
la règle, pour que la référence ne change jamais d'appareil : iPhone 16, 393 ×
852 points, à taille de texte système réduite — exactement ce que reproduit le
simulateur « iPhone 16 (référence) ». Ne pas produire soi-même les captures
depuis la build macOS de l'app Flutter, sauf impossibilité : sa fenêtre a une
autre largeur et ignore le réglage de taille de texte, ce qui oblige à changer
d'échelle à chaque mesure et fausse les comparaisons. Demander la capture, et
attendre.

Trois règles tirées des premiers écrans portés, chacune née d'une erreur réelle
— le détail des cas est dans [AVANCEMENT.md](AVANCEMENT.md).

- **Lire le style rendu, pas le style écrit.** Le code Dart peut demander une
  graisse que Flutter n'applique pas. En cas de doute, mesurer la capture au
  pixel plutôt que se fier à la source.
- **Valider chaque écran sur simulateur iPhone**, jamais sur la seule lecture du
  code. C'est ainsi qu'ont été trouvés le vide sous la barre de titre, le liseré
  d'ombre, et l'absence de message à l'annulation d'une restauration.
- **Aligner la taille de texte avant de comparer.** C'est la *seule* variable
  qui déplace la taille des polices. Les captures de référence de Yannick sont
  prises avec un réglage système réduit, d'environ 0,94 ; pour comparer, aligner
  le simulateur avec `xcrun simctl ui <appareil> content_size medium`.
  L'appareil, lui, n'entre pas en jeu : le même libellé mesure 92,0 points sur
  iPhone 16 comme sur iPhone 17 Pro. Les mesures se font en **points**, jamais
  en pixels, chaque capture étant divisée par l'échelle de son appareil — la
  résolution est donc déjà neutralisée.
- **Ce qu'on cherche, c'est la cohérence de l'app, pas l'égalité avec une
  capture.** La mesure au pixel n'est qu'un outil de détection : elle a révélé
  que les libellés du tiroir étaient 25 % trop gros, ce qu'aucun coup d'œil
  n'aurait attrapé. Une fois l'écart expliqué, c'est le rendu proportionné qui
  fait foi.

**Appareil de référence** : iPhone 16, 393 × 852 points. Déduit sans rien
supposer, en mesurant la largeur du tiroir Material, fixée à 304 points par le
framework. Un simulateur « iPhone 16 (référence) » est créé pour cela.

## Conventions Git

Consignes de Yannick, à appliquer sans exception.

1. **Ne jamais committer sans y être invité.**
2. **Ne pas suggérer de committer** après une modification — Yannick décide du moment.
3. **S'identifier systématiquement comme co-auteur** du commit.
4. **Messages de commit en français**, conformes à la norme *conventional commits* : `type(portée): description`, par exemple `feat(liste): ...`, `fix(tiroir): ...`.
5. **Ne jamais pousser sur le dépôt distant sans y être invité.**
6. **Ne pas suggérer de pousser** après un commit — Yannick décide du moment.

En pratique : terminer une tâche en décrivant ce qui a changé, sans mention de commit ni de push. N'aborder Git que sur demande, ou pour signaler un fait qui concerne directement Yannick — un conflit, un fichier indûment versionné.

### Branches et fusion (depuis le 12 septembre 2026)

`main` est **protégée** sur GitHub, Yannick compris : plus aucun push direct. Le travail se fait sur une branche, poussée régulièrement, puis fusionnée par *pull request*. Il n'y a normalement **jamais plusieurs branches en parallèle**.

La protection exige un check `Compilation et tests iOS` au vert, une branche à jour avec `main`, un historique linéaire — donc **squash ou rebase, jamais de commit de fusion** —, et interdit force-push et suppression de `main`.

**On fusionne en rebase**, pour garder distincts les commits fonctionnels d'une
même branche. Le coût est assumé : GitHub rejoue les commits côté serveur, leurs
empreintes changent, et les signatures GPG d'origine ne valent plus rien. Ils
apparaissent donc « unverified » sur `main`, GitHub ne re-signant que les
commits dont il est lui-même l'auteur — ceux d'un squash. La signature reste
vérifiable sur la branche tant qu'elle existe. *(Décidé le 13 septembre 2026,
après que l'écart avec les commits d'avant la protection a été remarqué.)*

Le workflow GitHub se déclenche sur **toutes** les branches, sans déclencheur `pull_request` : une exécution lancée par un push satisfait déjà le check exigé, GitHub rattachant les résultats au commit de tête et non à l'événement. Le mode strict referme le seul angle mort de ce choix, la branche devant contenir tout `main` avant fusion.

**Un push sur `dev` déclenche une livraison TestFlight**, Xcode Cloud surveillant cette branche depuis le 20 septembre 2026, sur la fiche d'app du bundle identifier de développement. `main` ne déclenche plus rien : on y fusionne pour marquer un jalon, pas pour livrer. *(Auparavant, c'était `main` qui était surveillée, et toute fusion livrait.)*

Les commits restent soumis aux six règles ci-dessus : jamais sans invitation, et la suppression d'une branche fusionnée en squash réclame `git branch -D`, le squash ayant récrit les commits. Vérifier `git diff main <branche>` avant de forcer.

## Décisions prises (12 septembre 2026)

- **Firebase Analytics** : retiré. Pas de télémétrie dans la version native, ce qui aligne l'app sur la mention « aucune donnée collectée » de la fiche App Store.
- **Notifications locales** : retirées pour le moment. Elles ne fonctionnaient pas côté Flutter et étaient déjà commentées ; on ne les porte pas.
- **Scaffold** : xcodegen, `project.yml` à la racine, source de vérité. Après toute modification de `project.yml`, relancer `xcodegen generate`. Le `NannyPlus.xcodeproj` produit est malgré tout versionné, comme sur Clepsydre, pour qu'Xcode Cloud trouve le projet et son schéma partagé.
- **Premier écran** : la liste des enfants, comme dans la version actuelle.
- **Bundle identifier** : `ch.yannickmauray.nannyplusios`. *(Révisé le 20 septembre 2026 : il valait `ch.frenchguy.nannyplus`, identique à l'app Flutter, pour un remplacement direct sur l'App Store.)* Le portage prend son propre identifiant afin que sa version TestFlight cohabite avec la production, au lieu de la remplacer.

  **La contrepartie est de taille** : le conteneur d'une app iOS est indexé par son bundle identifier. La version native n'ouvre donc plus `Documents/childcare.db` de l'app Flutter, mais le sien, vide. Elle ne reprend plus les données existantes toute seule — il faut passer par une restauration de sauvegarde.

  Le jour du remplacement sur l'App Store, reprendre `ch.frenchguy.nannyplus` rendra la base existante visible sans import, le chemin étant resté le même. Et App Store Connect demande une fiche d'app distincte pour le nouvel identifiant, avec son propre compteur de builds.
- **Traductions** : abandonnées. La version native est en français uniquement, toutes les chaînes en dur. Les libellés sont repris de `assets/i18n/fr.po` pour rester au mot près.
- **Ordre des boutons des boîtes de confirmation** : on garde l'ordre natif de SwiftUI, l'annulation à gauche et la confirmation à droite. Flutter affichait l'inverse (« Oui » puis « Non »), plaçant l'action confirmante sous le pouce. Le coût assumé est transitoire : une utilisatrice habituée à l'ancienne disposition peut se tromper les premières fois.
- **Cible macOS abandonnée** (12 septembre 2026). Elle ne servait qu'à compiler et lancer sans simulateur ; le simulateur s'étant révélé assez réactif, elle ne payait plus son coût. Son retrait a supprimé une dizaine de branches conditionnelles de plateforme dans le code — feuille de partage contre panneau d'enregistrement, mode édition de liste, barre de navigation, ouverture d'URL. **Le projet ne vise plus qu'iOS.** Le dossier `macos/` du projet Flutter reste utile comme source de captures de référence, lui.
- **Numérotation de version** : **2.0.0**, train propre au portage. *(Révisé le 12 septembre 2026 : le plan initial, décrit plus bas, alignait la native sur le 1.26.4 de la production avec un build 196. Abandonné au moment de la première archive — voir « Livraison » dans [AVANCEMENT.md](AVANCEMENT.md).)*

  Le numéro de build ne vient plus de `project.yml` mais d'Xcode Cloud : `ci_scripts/ci_post_clone.sh` y reporte `$CI_BUILD_NUMBER` avant `xcodegen generate`. Xcode Cloud tient ce compteur mais ne l'écrit pas dans l'app ; sans cette étape, chaque exécution reprendrait le même numéro et App Store Connect la rejetterait comme doublon. Le `CURRENT_PROJECT_VERSION: "1"` de `project.yml` n'est plus qu'une valeur de repli pour les compilations locales. Première livraison : **2.0.0 (3)**.

  Ce qui suit décrit le raisonnement d'origine, conservé pour la généalogie de la décision et parce que la mécanique Flutter y est documentée.

  *Côté Flutter*, la version vient du `pubspec.yaml`. `flutter build` la recopie dans `ios/Flutter/Generated.xcconfig` sous `FLUTTER_BUILD_NAME` et `FLUTTER_BUILD_NUMBER`, et l'`Info.plist` du projet iOS y renvoie par `$(FLUTTER_BUILD_NAME)` / `$(FLUTTER_BUILD_NUMBER)`. Les `MARKETING_VERSION = 1.0.0` et `CURRENT_PROJECT_VERSION = 6` que porte encore le `project.pbxproj` sont des vestiges inutilisés. Le `+9999` du `pubspec` est un repère local : le vrai numéro de build est posé à la livraison par **Codemagic**, dont le workflow est configuré dans l'interface web et non dans le dépôt — d'où l'absence de tout fichier de CI côté Flutter, et l'écart entre le `pubspec` local (1.26.3) et la production (1.26.4, build 195).

  **Changement de CI, et risque de continuité.** Le projet natif passe à Xcode Cloud, pas à Codemagic. Xcode Cloud tient son propre compteur de builds, qui démarre à 1 et ignore tout des 195 builds déjà livrés par Codemagic. Si le premier téléversement sort un numéro inférieur ou égal à 195 pour la version 1.26.4, App Store Connect le refusera. À régler avant la première livraison, soit en fixant le numéro de départ du workflow Xcode Cloud au-dessus de 195, soit en gardant la main sur `CURRENT_PROJECT_VERSION` dans `project.yml`.

  *Côté natif*, le chemin est plus court : `project.yml` porte `MARKETING_VERSION` et `CURRENT_PROJECT_VERSION`, XcodeGen les écrit dans le projet, et `GENERATE_INFOPLIST_FILE` les reporte dans `CFBundleShortVersionString` et `CFBundleVersion`. `project.yml` joue donc le rôle du `pubspec.yaml`, et c'est le seul endroit à modifier. L'app relit ces valeurs à l'exécution via `Bundle.main`, comme `package_info_plus` le faisait. Le `pubspec.yaml` du projet Flutter affiche 1.26.4+9999 : le `+9999` est un repère local, le numéro de build réel étant posé à la livraison par la CI, d'où le 195 en production. Le projet natif part donc de `MARKETING_VERSION: 1.26.4` et `CURRENT_PROJECT_VERSION: 196`. **Le build doit être strictement supérieur à 195** : App Store Connect refuse un numéro déjà téléversé pour la même version, et livrer 195 ferait échouer l'envoi sur TestFlight.
