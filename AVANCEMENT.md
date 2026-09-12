# Nanny+ natif — Avancement

Où en est le portage. Ce que l'on construit et pourquoi est dans
[SPECS.md](SPECS.md).

## Notes de mise à jour

Ce qui change pour l'utilisatrice en passant de la version Flutter à la version
native. Cette liste s'étoffe au fil du portage et servira de base aux notes de
version de l'App Store. Tout ce qui n'y figure pas est réputé identique — c'est
la contrainte du projet.

### Dans cette version

1. **L'application est entièrement récrite en natif iOS.** C'est le changement
   majeur, et il doit rester invisible : mêmes écrans, mêmes gestes, mêmes
   défauts d'ergonomie qu'avant. Les données existantes sont reprises telles
   quelles, sans import ni sauvegarde préalable — l'app native ouvre le même
   fichier que l'ancienne.

2. **Plus aucune donnée ne quitte l'appareil.** Firebase Analytics envoyait un
   événement à chaque lancement ; il est retiré. L'app ne contacte désormais
   aucun serveur, ce qui la met enfin en accord avec ce qu'annonce sa fiche App
   Store.

3. **Politique de confidentialité récrite.** La section sur Google Analytics
   disparaît, devenue sans objet. Le reste est corrigé : trois fautes de
   français, une introduction qui contredisait le corps du texte, et plusieurs
   tournures calquées de l'anglais. Les titres de section s'affichent enfin en
   gras, comme le code Flutter le demandait sans y parvenir. Texte de référence
   dans [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md).

4. **Notifications locales retirées.** Anniversaires et factures impayées : le
   code était déjà commenté côté Flutter et ne fonctionnait pas. Rien ne change
   en pratique, mais la dépendance disparaît.

5. **Les boîtes de confirmation ont été remises d'aplomb.** Leur titre disait
   « Supprimer » quelle que soit l'action, y compris pour archiver ou
   désarchiver un dossier ; il suit désormais ce qu'on s'apprête à faire. Et les
   boutons adoptent l'ordre habituel sur iOS — « Non » à gauche, « Oui » à
   droite — au lieu de l'ordre inverse. **Ce second point demande une petite
   accoutumance** : le geste appris sur l'ancienne version confirme désormais là
   où il annulait.

6. **L'application n'est plus disponible qu'en français.** Les traductions
   anglaises sont abandonnées. **C'est la seule régression visible de cette
   liste** : une utilisatrice dont l'appareil est en anglais voyait jusqu'ici
   l'app en anglais, elle la verra désormais en français.

### À décider, après le portage

- **Version minimale d'iOS.** La cible est aujourd'hui iOS 26, reprise des
  réglages Flutter. Si c'est un effet de bord d'une mise à jour d'Xcode plutôt
  qu'un choix, l'abaisser rendrait l'app à nouveau installable sur des appareils
  plus anciens — une amélioration à annoncer, pas une divergence.
- **Politique de confidentialité publiée ailleurs.** Celle de la fiche App Store
  et du site mentionne toujours Google Analytics et diverge donc de celle de
  l'app.
- **Bascule de CI, de Codemagic vers Xcode Cloud.** Sans incidence pour
  l'utilisatrice, mais le compteur de builds repart de zéro alors que la
  production en est à 195. À régler avant la première livraison TestFlight,
  détail dans [SPECS.md](SPECS.md).
- **Nettoyage de la base de données.** Sous réserve de l'analyse préalable
  de Yannick. Selon ce qui est supprimé, l'effet peut être visible.

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
- Les garde-fous du menu contextuel sont reproduits : un dossier ayant des prestations en attente ne peut pas être archivé, un dossier ayant la moindre prestation ne peut pas être supprimé. En revanche le titre de la boîte de confirmation, « Supprimer » y compris pour un archivage côté Flutter, **a été corrigé** : il suit désormais l'action (« Archiver », « Désarchiver », « Supprimer »). `ChildFolderAction` porte le titre avec le message, et un test le vérifie.

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
- À la taille de texte par défaut, « Réinitialiser les messages d'aide » passe sur deux lignes : 226 points de texte pour 216 disponibles dans un tiroir de largeur fixe. **Vérifié sur l'app Flutter elle-même** (build macOS Release) : elle fait exactement pareil.

Seul « Réinitialiser les messages d'aide » est fonctionnel (suppression des clés `flutter.help_*`), ainsi que « Réinitialiser la base de données », réservé aux compilations de debug comme le `kDebugMode` de Flutter. **Attention** : sur la cible macOS, cet élément supprime la base réelle, le conteneur étant partagé avec l'app Flutter. Le risque existe déjà à l'identique côté Flutter.

**Outillage d'essai** : `cliclick` est installé. La fenêtre du simulateur expose l'écran de l'appareil comme un groupe d'accessibilité en 1:1, ce qui permet de convertir points appareil → écran sans deviner de facteur de zoom (`position of group 1` de la fenêtre du processus Simulator). Il faut activer la fenêtre avant de cliquer, sinon le clic est absorbé.

**Écran Politique de confidentialité porté** (`Sources/Shared/Features/PrivacySettings/`). Écran statique, ouvert depuis le tiroir en modale plein écran — le `fullscreenDialog: true` de Flutter. La barre de titre a été sortie dans `Sources/Shared/Features/Shell/AppBar.swift` pour être partagée entre les écrans ; elle prend un bouton de gauche paramétrable (menu ou croix de fermeture).

La leçon du tiroir s'est confirmée : les titres de section portent `fontWeight: FontWeight.bold` dans le Dart et **ne sont pas en gras** à l'écran. Mesuré sur trois titres : Poppins Regular 14, soit `bodyMedium`, exactement comme les paragraphes. Seul l'espacement distingue un titre d'un paragraphe (16 points au-dessus, 8 en dessous).

Contrôle de mise en page contre la référence : l'écart entre le bas du bandeau incurvé et la première ligne de texte est de 49 points côté Flutter et 48 côté natif, et le bas du bandeau tombe à 107 points du haut du contenu dans les deux cas.

**C'est le seul écran dont le texte s'écarte volontairement de la version Flutter**, sur décision de Yannick.

- La section « Google Analytics » est retirée : la version native n'embarque aucune télémétrie, et ce paragraphe décrivait donc quelque chose que l'app ne fait plus. Son retrait rendait par ailleurs l'introduction franchement fausse, puisqu'elle annonçait que l'app « collecte, utilise, partage » des informations personnelles quand le corps du texte dit l'inverse.
- Trois fautes corrigées : « aucune **données** », « et **celles** des enfants » (il s'agit de la vie privée, singulier), « s'assurer qu'ils **soient** informés » (l'indicatif s'impose après *s'assurer que*).
- Anglicismes récrits (« à l'occasion », « maintenir la conformité avec », « préavis adéquat », « communiquer avec nous en utilisant ce qui suit »), guillemets droits remplacés par des guillemets français à espace insécable, apostrophes typographiques partout, et « sur le téléphone » devenu « sur votre appareil », l'app tournant aussi sur iPad.
- Date portée au 12 septembre 2026.
- **Les titres de section sont mis en gras.** Le Dart le demandait déjà (`fontWeight: FontWeight.bold`) sans que Flutter l'applique. C'est donc moins une divergence qu'un défaut corrigé : l'écran rend enfin ce que son code décrivait.

Le texte de référence est dans [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md), à la racine. **Les deux doivent rester synchronisés** — un contrôle automatique serait à écrire si l'écart devient un risque.

**Reste à faire** : la politique publiée ailleurs (fiche App Store, site) diverge désormais de celle de l'app. C'est le genre de document où ça se remarque.

**Nouvelle capacité d'outillage** : l'app Flutter est compilée pour macOS (`../nannyplus/build/macos/Build/Products/Release/nannyplus.app`) et peut être lancée et pilotée à la souris pour produire les captures de référence, sans dépendre de Yannick. Utiliser la build **Release** : en Debug, son tiroir contient l'entrée qui efface la base réelle.

**Écran Sauvegarder / Restaurer porté** (`Sources/Shared/Features/BackupRestore/`). Le mécanisme reste volontairement fruste : « Sauvegarder » partage le fichier `childcare.db` lui-même, « Restaurer » le remplace par un fichier choisi, sans aucun contrôle de format.

Le `ListTile` a révélé la règle qui manquait au tiroir : `list_tile.dart` ligne 1735 de Flutter choisit `bodyLarge` quand la tuile est dans un `Drawer` et `titleMedium` sinon. D'où des libellés en Poppins Medium 14 dans le tiroir et en **Poppins gras 16** ici, mesurés à 1 % près sur la référence. Ce n'était donc pas un caprice de `google_fonts` mais un comportement documenté de Material.

Trois écarts corrigés après essai réel sur simulateur, tous invisibles à la lecture du code :

- `fileImporter` de SwiftUI **n'appelle pas son gestionnaire à l'annulation**, là où `FilePicker` de Flutter renvoie `null` et déclenche le message d'erreur. L'annulation est désormais détectée à la fermeture sans résultat, ce qui restitue le défaut d'origine : annuler affiche « Erreur lors de la restauration ».
- Le message de succès de la restauration s'affichait dans la modale, qui se referme aussitôt — l'utilisatrice ne voyait rien. Le `ScaffoldMessenger` de Flutter vit au-dessus de la navigation et survit au changement d'écran. Le bandeau a donc été remonté dans `MainTabView`, qui le porte pour toute l'app ; `SnackbarPresenter` est partagé.
- Le message de sauvegarde s'affiche **sans attendre le résultat du partage**, comme côté Flutter : annuler la feuille affiche quand même « sauvegardée avec succès ». Défaut conservé.

Aller-retour vérifié de bout en bout sur simulateur : sauvegarde vers Fichiers, modification de la base pour qu'elle diverge, restauration, puis contrôle que l'empreinte SHA-256 de la base de l'app est redevenue celle de la sauvegarde et que la modification témoin a disparu.

### Reste à faire sur ces fondations

- `insertSampleData` (jeu de démonstration inséré à la première ouverture : tarifs, enfants, prestations, facture, réglages de facturation et logo) n'est pas porté. À traiter avec l'onboarding.
- Sur l'écran liste : le formulaire enfant (création et duplication), la navigation vers la fiche enfant, et la boîte de dialogue d'accueil ne sont pas portés — les boutons correspondants sont en place mais sans action.
- Les garde-fous d'archivage et de suppression sont couverts par `Tests/ChildFolderActionTests.swift`. La décision a été extraite de la vue dans `ChildFolderAction`, précisément pour pouvoir la vérifier : ce sont eux qui empêchent de supprimer un dossier portant des prestations et des factures. Le parcours complet (menu, boîte de confirmation, bandeau) n'a en revanche jamais été cliqué, bien que `cliclick` soit désormais disponible.
- Sur macOS, la barre de défilement reste visible là où Flutter n'en montrait pas ; c'est le réglage système du Mac, sans effet sur iOS.

## À revoir une fois le portage initial terminé

Points volontairement laissés de côté pendant le portage, à traiter après.

- **Cibles de déploiement iOS 26.0 / macOS 26.0** — reprises des `Podfile` Flutter. C'est restrictif pour une app grand public : à confirmer, et à abaisser si la valeur actuelle vient d'une mise à jour d'Xcode plutôt que d'un choix délibéré. Une ligne à changer dans `project.yml`.
- **Nettoyage de la base de données** — il y a du ménage à faire dans les données existantes. Yannick doit d'abord étudier ce qui est concerné ; à ne pas entreprendre avant cette analyse, et surtout pas pendant le portage, pour que les deux versions restent comparables sur des données identiques.

## Prochaine étape

Écran suivant dans l'ordre convenu : la fiche enfant. Capture d'écran de la version Flutter à fournir.
