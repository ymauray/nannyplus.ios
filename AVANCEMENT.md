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

6. **La grille tarifaire s'appelle « Tarifs » et se réordonne autrement.** Elle
   s'intitulait « Prestations », le même nom que l'onglet du dossier enfant qui
   liste les heures de garde. Et pour changer l'ordre des tarifs, un crayon fait
   désormais apparaître les poignées habituelles d'iOS, au lieu d'une poignée
   présente en permanence sur chaque ligne.

7. **L'application n'est plus disponible qu'en français.** Les traductions
   anglaises sont abandonnées. **C'est la seule régression visible de cette
   liste** : une utilisatrice dont l'appareil est en anglais voyait jusqu'ici
   l'app en anglais, elle la verra désormais en français.

8. **Le numéro de version saute de 1.26.4 à 2.0.0.** La réécriture ouvre son
   propre train de version, plutôt que de prolonger celui de l'app Flutter.
   Sans conséquence sur les données ni sur la mise à jour depuis l'App Store,
   qui reste une mise à jour ordinaire de la même application.

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

## Où on en est

| Écran | État |
|---|---|
| Liste des enfants | **fait**, sauf création et duplication |
| Tiroir — Sauvegarder / Restaurer | **fait**, aller-retour vérifié |
| Tiroir — Politique de confidentialité | **fait** |
| Tiroir — Réinitialiser les messages d'aide | **fait** |
| Tiroir — Réinitialiser la base (debug) | **fait** |
| Dossier enfant | coque et trois onglets **en maquette** ; aucun contenu porté |
| Options — menu | **fait** |
| Options — Tarifs | **fait** : lecture, création, modification, suppression, réordonnancement |
| Options — Déductions | **fait**, idem |
| Options — Paramètres de l'application | **fait** |
| Options — Paramètres de la facture | **fait** |
| Options — Relevés | **fait** : liste, décompte annuel et relevé mensuel en PDF |
| Options — Planning hebdomadaire | à porter (PDF) |
| Options — Planning annuel | à porter (PDF) |
| Options — Planning des congés | à porter |
| Formulaire enfant | à porter |
| Saisie des prestations | à porter |
| Facturation | à porter, y compris le PDF et la relance par SMS |
| Jeu de données de démonstration | à porter avec l'onboarding |

## État d'avancement

**Phase 2 (fondations) faite.** Le projet compile, et l'app lit la base réelle (24 enfants, 1787 prestations, 266 factures) sans conversion. *Le projet a d'abord porté une cible macOS, retirée depuis ; les paragraphes ci-dessous qui la mentionnent relatent ce qui s'est passé à l'époque.*

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

Le workflow GitHub est réduit en conséquence : pas de job « module partagé » (il n'y a pas d'équivalent de `ClepsydreCore`) ni de job « bundle complet ». Restent la compilation et les tests iOS. Le job de compilation macOS qui l'accompagnait a été retiré avec la cible.

**Deux défauts d'affichage corrigés après essai sur simulateur iPhone**, tous deux invisibles sur la cible macOS :

- Un vide de la hauteur de l'encoche séparait la barre de titre du bandeau. La barre cumulait une marge haute égale à la zone sûre **et** un `ignoresSafeArea` : le fond remontait mais la hauteur restait réservée. Seul le fond déborde désormais sous la barre d'état, la vue gardant ses 56 points sous la zone sûre.
- Un liseré sombre marquait la jonction entre la barre de titre et le bandeau : l'ombre du bandeau, projetée sur tout son pourtour, débordait vers le haut. La barre de titre est maintenant peinte par-dessus (`zIndex`), ce que fait Flutter, où la `SliverAppBar` recouvre le bandeau.

Leçon de méthode, et l'une des raisons du retrait de la cible macOS : elle n'a ni encoche ni zone sûre, et masquait donc toute une catégorie de défauts. Chaque écran porté doit être vu sur simulateur iPhone avant d'être considéré comme terminé.

**Tiroir de navigation porté** (`Sources/Shared/Features/Shell/MainDrawer.swift`). SwiftUI n'a pas d'équivalent du `Drawer` de Material : le panneau de 304 points, le voile et l'animation sont dessinés à la main dans `MainTabView`.

Le portage a demandé de mesurer la capture de référence au pixel plutôt que de suivre le code Dart, et c'est instructif pour la suite :

- **Le `fontWeight: FontWeight.bold` du Dart ne s'applique pas.** Les libellés du tiroir se mesurent en graisse 500 (Medium), pas 700. `google_fonts` résout une famille par graisse : forcer w700 sur une famille qui ne contient que la w500 retombe sur cette dernière. Sur l'écran liste en revanche, le gras fonctionne, parce que le style vient de `titleMedium` que `GoogleFonts.poppins` a résolu en gras à la construction du thème. **Leçon : sur cette app, lire le style rendu, pas le style écrit.**
- **Styles réels du tiroir** : titres en `bodyLarge` de la typographie Material 2014, soit 14 points en graisse 500 ; ligne de version en `bodyMedium`, 14 points en graisse 400. Vérifié sur trois chaînes de longueurs différentes, à 0,3 % près.
- **La capture de référence a été prise avec une taille de texte système réduite** (environ 0,93). Les polices suivent désormais le réglage système, comme Flutter : `Font.custom(_:size:)` et non `fixedSize:`. Pour comparer une capture à la référence, aligner le simulateur avec `xcrun simctl ui <appareil> content_size medium`.
- À la taille de texte par défaut, « Réinitialiser les messages d'aide » passe sur deux lignes : 226 points de texte pour 216 disponibles dans un tiroir de largeur fixe. **Vérifié sur l'app Flutter elle-même** (build macOS Release) : elle fait exactement pareil.

Seul « Réinitialiser les messages d'aide » est fonctionnel (suppression des clés `flutter.help_*`), ainsi que « Réinitialiser la base de données », réservé aux compilations de debug comme le `kDebugMode` de Flutter. **Attention** : sur la cible macOS, cet élément supprime la base réelle, le conteneur étant partagé avec l'app Flutter. Le risque existe déjà à l'identique côté Flutter.

**Outillage d'essai**

- Le simulateur de travail est **« iPhone 16 (référence) »**, identique à l'appareil de Yannick : 393 × 852 points, la même échelle que ses captures. Les autres simulateurs sont éteints.
- Il tourne sur une copie de la base réelle. Pour la réinjecter après une réinstallation :

  ```sh
  xcrun simctl terminate <appareil> ch.frenchguy.nannyplus
  cp ~/Library/Containers/ch.frenchguy.nannyplus/Data/Documents/childcare.db \
     "$(xcrun simctl get_app_container <appareil> ch.frenchguy.nannyplus data)/Documents/"
  ```

  Attention : le conteneur change d'identifiant à chaque réinstallation, il faut donc le résoudre à nouveau et non réutiliser un chemin noté plus tôt.
- `cliclick` est installé. La fenêtre du simulateur expose l'écran de l'appareil comme un groupe d'accessibilité en 1:1, ce qui permet de convertir points appareil → écran sans deviner de facteur de zoom (`position of group 1` de la fenêtre du processus Simulator). Il faut activer la fenêtre avant de cliquer, sinon le clic est absorbé.
- Pas de commande de défilement dans `cliclick` : un glisser (`dd:` … `m:` … `du:`) fait l'affaire.
- Script de clic, à recréer dans un dossier temporaire au besoin. Il prend des coordonnées en **points de l'appareil**, celles qu'on lit sur une capture divisée par son échelle :

  ```sh
  #!/bin/sh
  set -e
  osascript -e 'tell application "Simulator" to activate' >/dev/null
  sleep 1
  ORIGIN=$(osascript -e 'tell application "System Events" to tell process "Simulator" \
    to tell window 1 to get position of group 1')
  OX=$(echo "$ORIGIN" | cut -d, -f1 | tr -d ' ')
  OY=$(echo "$ORIGIN" | cut -d, -f2 | tr -d ' ')
  cliclick "c:$((OX + $1)),$((OY + $2))"
  ```

  Viser le **centre visuel** d'un contrôle ne suffit pas toujours : la zone sensible d'un interrupteur SwiftUI commence quelques points plus bas que son dessin. En cas de clic sans effet, balayer quelques hauteurs avant de conclure à un défaut.

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

**Recours en dernier ressort** : l'app Flutter est compilée pour macOS (`../nannyplus/build/macos/Build/Products/Release/nannyplus.app`) et peut être lancée et pilotée à la souris. À n'employer que si Yannick ne peut pas fournir la capture, la règle étant que les références viennent de son téléphone — voir la méthode de travail dans [SPECS.md](SPECS.md). Sa fenêtre a une autre largeur et ignore le réglage de taille de texte, il faut donc recalculer l'échelle. Et utiliser la build **Release** : en Debug, son tiroir contient l'entrée qui efface la base réelle.

**Écran Sauvegarder / Restaurer porté** (`Sources/Shared/Features/BackupRestore/`). Le mécanisme reste volontairement fruste : « Sauvegarder » partage le fichier `childcare.db` lui-même, « Restaurer » le remplace par un fichier choisi, sans aucun contrôle de format.

Le `ListTile` a révélé la règle qui manquait au tiroir : `list_tile.dart` ligne 1735 de Flutter choisit `bodyLarge` quand la tuile est dans un `Drawer` et `titleMedium` sinon. D'où des libellés en Poppins Medium 14 dans le tiroir et en **Poppins gras 16** ici, mesurés à 1 % près sur la référence. Ce n'était donc pas un caprice de `google_fonts` mais un comportement documenté de Material.

Trois écarts corrigés après essai réel sur simulateur, tous invisibles à la lecture du code :

- `fileImporter` de SwiftUI **n'appelle pas son gestionnaire à l'annulation**, là où `FilePicker` de Flutter renvoie `null` et déclenche le message d'erreur. L'annulation est désormais détectée à la fermeture sans résultat, ce qui restitue le défaut d'origine : annuler affiche « Erreur lors de la restauration ».
- Le message de succès de la restauration s'affichait dans la modale, qui se referme aussitôt — l'utilisatrice ne voyait rien. Le `ScaffoldMessenger` de Flutter vit au-dessus de la navigation et survit au changement d'écran. Le bandeau a donc été remonté dans `MainTabView`, qui le porte pour toute l'app ; `SnackbarPresenter` est partagé.
- Le message de sauvegarde s'affiche **sans attendre le résultat du partage**, comme côté Flutter : annuler la feuille affiche quand même « sauvegardée avec succès ». Défaut conservé.

Aller-retour vérifié de bout en bout sur simulateur : sauvegarde vers Fichiers, modification de la base pour qu'elle diverge, restauration, puis contrôle que l'empreinte SHA-256 de la base de l'app est redevenue celle de la sauvegarde et que la modification témoin a disparu.

**Dossier enfant : la coque des trois onglets** (`Sources/Shared/Features/ChildDetail/`). Barre de titre avec retour et crayon, bandeau incurvé portant le total à facturer de l'enfant, barre d'onglets Prestations / Factures / Information. Vérifié sur simulateur contre les trois captures de référence.

- La barre d'onglets est dessinée à la main : libellé sélectionné en Poppins gras 14, les autres en régulier à 70 % d'opacité, trait de 2 points en couleur secondaire, fond de page. Hauteur 48 points, marges 8 sur les côtés et 12 en bas, comme `UISliverTabBarPeristantHeader`.
- Le dossier s'empile par-dessus tout l'écran, barre d'onglets du bas comprise, via une `NavigationStack` dont la barre système est masquée — équivalent du `Navigator.push` de Flutter, avec le glissement de retour en prime. Un dossier archivé ne s'ouvre pas, `onTap` valant `null` dans ce cas côté Flutter.
- Le total du bandeau est réel : somme des prestations non facturées de l'enfant, **hors tarifs techniques** (`priceId < 0`), filtre que `loadServices` applique aussi. Recoupé avec la liste : 1281.00 pour Maé Burri des deux côtés.

**Les trois contenus sont des maquettes** (`TabMockups.swift`), à reprendre écran par écran :

- *Prestations* : vide, avec le bouton flottant. `ServiceListTabView` n'est pas porté.
- *Factures* : l'état vide des captures — « Aucune facture ouverte trouvée » et le lien vers les factures payées. Aucune facture n'est réellement lue.
- *Information* : les sept cartes, alimentées par les champs du dossier réel puisqu'ils sont déjà en mémoire. Rien n'est modifiable, et le planning n'est pas lu — la carte affiche toujours « Aucun planning défini ».

Le crayon d'édition et les boutons flottants sont en place mais sans action : `ChildForm` et la saisie de prestations restent à porter.

**Menu Options porté** (`Sources/Shared/Features/Options/`). Le second onglet n'est plus une page vide : huit tuiles, géométrie et typographie recoupées avec la référence à 0,5 % près. **Aucune destination n'est portée** — les tuiles n'ouvrent rien.

Deux libellés surprennent mais sont fidèles : la grille tarifaire s'appelle « Prestations », le même mot que l'onglet du dossier enfant, et « Deductions » ressort sans accent, faute de traduction dans `fr.po`. Défauts conservés — à trancher si on veut les corriger comme le titre des boîtes de confirmation.

Les icônes sont des approximations SF Symbols des icônes Material ; Yannick les a validées telles quelles. La seule vraiment éloignée est celle du planning hebdomadaire.

**Grille tarifaire portée** (`Sources/Shared/Features/PriceList/`, `Price.swift`, `PricesRepository.swift`). Liste et formulaire, lus et écrits dans la base réelle. **L'écran s'appelle « Tarifs »**, et la tuile du menu Options avec lui : `fr.po` traduit `Price list` par « Prestations », soit le mot que porte déjà l'onglet du dossier enfant qui liste les heures de garde. Deux écrans, un seul nom — corrigé.

- Les cartes reprennent la surcharge de `CardScrollView` : rayon **1** — coins quasi droits, contrairement aux 12 points du reste de l'app — marges de 8 et 5, marge intérieure de 16.
- Le titre de la carte est en **Poppins Regular 14**, pas en gras, bien que le Dart demande `fontWeight: FontWeight.bold`. Même mécanique que le tiroir, vérifiée à la mesure.
- Le titre du formulaire annonce « Créer un nouveau tarif » **même quand on modifie un tarif existant** : le Dart passe `Create new price` dans les deux cas. Défaut conservé.
- La suppression est **physique**, alors que la table porte une colonne `deleted` jamais utilisée. Aucune ligne de la base réelle ne la porte à 1.
- `reorder` côté Flutter recharge tous les tarifs, y compris ceux marqués supprimés, alors que la liste affichée les exclut : les indices se décaleraient s'il en existait. Défaut latent, non reproduit — on réordonne à partir de la liste visible.

**Réordonnancement par mode édition**, sur décision de Yannick plutôt que de reproduire la poignée permanente de Flutter. Un crayon dans la barre de titre bascule en mode édition : les poignées du système apparaissent à droite, le bouton flottant s'efface, et le crayon devient une coche pour sortir. Hors édition, les cartes occupent toute la largeur. Vérifié en base : un glisser réécrit bien les `sortOrder`.

C'est le premier endroit où l'on s'écarte de la version Flutter pour faire **mieux** plutôt que pour faire **pareil**. Le constat qui l'a motivé vaut pour la suite : ce code n'a pas à être porté à l'identique quand l'identique est mauvais.

**Le bandeau incurvé est désormais posé sur tous les écrans**, sur décision de Yannick, y compris le formulaire de tarif qui n'en a pas côté Flutter — celui-ci passe par `AppView` et non `UIView`. Conséquence assumée du même choix : le formulaire est en Poppins comme le reste, là où `AppView` impose SF Pro Text agrandi de 12,5 %. À revenir dessus si l'écart gêne.

**Cible macOS retirée.** Elle n'existait que pour compiler et lancer sans simulateur ; ce dernier s'est révélé assez réactif pour s'en passer. Ont disparu avec elle : la cible et son schéma dans `project.yml`, le fichier d'entitlements, le job macOS de GitHub Actions, et **toutes les conditionnelles de plateforme du code** — il n'en reste aucune. Le projet ne compile plus que pour iOS.

À noter : l'app Flutter compilée pour macOS, elle, reste précieuse comme source de captures de référence. C'est une autre chose que la cible native.

**Déductions portées** (`Sources/Shared/Features/Deductions/`, `Deduction.swift`, `DeductionsRepository.swift`). Liste, création, modification, suppression, réordonnancement par mode édition — même dispositif que les tarifs. Les valeurs `amount`/`percent` et `monthly`/`yearly` sont les chaînes stockées en base, conservées telles quelles ; seuls les libellés affichés sont traduits.

L'écran s'appelle « **Déductions** ». Côté Flutter il affiche « Deductions » sans accent, `fr.po` ne traduisant pas ce message et renvoyant l'original anglais. Corrigé, dans le menu comme dans le titre, comme le renommage en « Tarifs ».

**Encarts d'aide portés** (`Sources/Shared/Features/Shell/HelpCard.swift`). Encadré jaune que l'utilisatrice écarte d'une croix, et qui ne revient plus. La boucle complète a été vérifiée : écarter écrit la clé, l'encart reste masqué après relance, et « Réinitialiser les messages d'aide » du tiroir le fait revenir. Cela valide au passage cette entrée du tiroir, codée bien avant qu'un encart n'existe pour l'éprouver.

**La clé de préférence diffère volontairement.** Flutter emploie `help_<hashCode du texte d'aide>`, et le `hashCode` des chaînes de Dart n'est pas reproductible en Swift. On utilise un identifiant explicite — `help_deductions` — stable et lisible. Conséquence : un encart déjà écarté dans l'app Flutter réapparaîtra **une fois** dans la version native. Le préfixe `flutter.` est conservé, si bien que la réinitialisation du tiroir efface les deux formes.

**Paramètres de l'application portés** (`Sources/Shared/Features/AppSettings/`), **remis en forme** sur demande. L'écran d'origine aligne quatre champs nus séparés de filets, sans cartes, avec les interrupteurs violets par défaut de Material qui n'appartiennent à aucune palette de l'app. On reprend la mise en carte employée partout ailleurs et la couleur primaire.

Les quatre champs sont conservés, mais l'un change de libellé :

- **« Jours avant notification de facture impayée » devient « Jours avant de signaler une facture impayée ».** Ce réglage n'a rien de lié aux notifications locales retirées : il décide à partir de combien de jours le nom d'un enfant passe en rouge dans la liste. Son libellé décrivait un usage qui n'existe plus.
- **« Message de notification » reste tel quel.** Malgré son nom, il ne concerne pas non plus les notifications locales : c'est le gabarit du **SMS de relance envoyé aux parents** depuis le menu d'une facture, où `{{date}}` et `{{total}}` sont remplacés à l'envoi (`invoice_list_tab_view.dart`). Fonctionnalité bien vivante, à porter avec l'écran des factures.

**Piège de méthode** : ce champ avait d'abord été supprimé à tort, sur la foi d'un `grep` dont la sortie avait été tronquée par `head` — la seule occurrence utile était au-delà de la coupure. Ne jamais conclure à l'absence d'un usage depuis une sortie tronquée.

**Les deux réglages d'affichage des noms sont enfin éprouvés**, et l'un d'eux a révélé un défaut. Ils étaient codés depuis le premier écran sans qu'on puisse les faire varier.

- « Afficher le prénom avant le nom de famille » : vérifié, la liste passe de « Ellie Burri » à « Burri, Ellie ».
- « Trier la liste des enfants par nom de famille » : **il fonctionnait, mais l'effet ne se voyait qu'après relance de l'app.** Le tri vient d'un `ORDER BY` dans la requête ; rien ne rechargeait la liste au retour des réglages. C'est pour cette raison qu'il paraissait inopérant, côté Flutter comme ici — la version Flutter ne réinitialise pas davantage l'état de la liste après un enregistrement.
- **Correctif** : `OptionsView` prévient `MainTabView` à la fermeture des réglages, qui recharge le modèle. Les deux réglages s'appliquent désormais immédiatement, vérifié sans relancer l'app.

À noter pour les prochaines vérifications : `UserDefaults` écrit sur disque de façon différée. Relire le `.plist` juste après un enregistrement peut montrer l'ancienne valeur alors que l'app a bien pris la nouvelle — c'est l'écran qui fait foi, pas le fichier.

**Paramètres de la facture portés** (`Sources/Shared/Features/InvoiceSettings/`), **remis en forme** comme les paramètres de l'application : l'écran d'origine aligne ses champs sans cartes. Le contenu est identique — logo, deux lignes d'en-tête avec leur police, conditions de paiement, coordonnées bancaires, nom, adresse.

- Les sept polices de facture sont reprises de `FontUtils` (même ordre, mêmes fichiers) et chacune s'affiche dans sa propre fonte dans le menu, comme côté Flutter. `InvoiceFont` conserve à la fois la famille et le chemin d'asset Flutter, les deux étant stockés en préférence : les réglages déjà enregistrés restent lisibles.
- Le logo est lu et écrit dans `Documents/logo`, sans extension — le même emplacement que côté Flutter, donc un logo déjà choisi est repris tel quel.

**Deux pièges rencontrés, à retenir.**

- **Le nom PostScript d'une police ne vaut pas son nom de fichier.** « Mystery Quest » est livré dans `MysteryQuest-Regular.ttf` mais s'appelle `MysteryQuest`. Enregistrer par le nom PostScript faisait échouer le chargement, et l'assertion de `Poppins.register()` faisait planter l'app au démarrage — le garde-fou a bien joué son rôle. L'enregistrement se fait désormais par nom de fichier.
- **`plutil -extract` traite le point comme un séparateur de chemin.** `flutter.line1` était donc lu comme la clé `flutter` puis la clé `line1`, et l'extraction échouait en silence. Pour recopier des préférences Flutter vers le simulateur, passer par `plistlib` en Python puis `xcrun simctl spawn <appareil> defaults write`.

**Liste des relevés portée** (`Sources/Shared/Features/Statements/`). Une carte par année, le total annuel puis un rang par mois, montants **nets**. Les boutons PDF sont en place mais inertes : la génération n'est pas portée.

Règles de calcul, reprises telles quelles :

- Ne comptent que les prestations **facturées dont la facture est payée** (`s.invoiced = 1 AND i.paid = 1`).
- **Le mois en cours est écarté**, n'étant pas encore clos.
- Le net d'un mois applique les déductions de périodicité `monthly` : un pourcentage porte sur le brut du mois, un montant se retranche tel quel.
- Le total de l'année est la **somme des nets mensuels**, et non le brut annuel diminué d'une déduction annuelle.

**Tous les montants recoupés avec la référence** : 2026 à 16285.10 et ses neuf mois, 2025 à 26309.28 et les siens, au centime près.

**Décompte annuel en PDF porté** (`StatementPDF.swift`, `StatementPreviewView.swift`). Généré avec `UIGraphicsPDFRenderer`, A4, marges de 50 points. Les tailles reprennent celles du Dart, déjà multipliées par l'échelle de 0,75 qu'il applique. Le corps est en **Helvetica**, police par défaut du paquet `pdf` de Flutter ; seules les deux lignes d'en-tête utilisent la police choisie dans les réglages de facture. Bleu `#2196F3` et gris de ligne `#EEEEEE`, relevés dans le paquet `pdf` et confirmés sur le PDF de référence.

**Aération de la liste** : chaque rang fait 48 points de haut, la taille d'un `IconButton` de Material, plus 8 points de marge pour les mois — soit 56 points, mesurés à l'identique sur la référence. Sans cette contrainte, les rangs se réduisaient à la hauteur du texte et la liste paraissait tassée. C'est le genre de dimension qui ne se lit pas dans le code Dart : elle vient du composant, pas de la mise en page.

**Recoupé au centime avec le décompte annuel de référence** : les huit mois, le total brut 18149.00, la déduction -1863.90 et le total net 16285.10.

**L'aperçu s'écarte volontairement de Flutter.** Celui-ci utilise le `PdfPreview` du paquet `printing` et sa barre bleue « imprimer / partager ». On emploie ici l'aperçu de PDFKit et la feuille de partage du système, qui propose déjà Imprimer, Enregistrer dans Fichiers, Annoter, Mail et Messages — vérifié à l'écran. Rien à dessiner, et des gestes que l'utilisatrice connaît. C'est la réponse à la question « une solution élégante pour enregistrer le document ».

À noter pour la suite : le calcul du net dans le PDF n'est pas celui de la liste. Le PDF applique une déduction fixe mensuelle **autant de fois qu'il y a de mois** dans le décompte, là où la liste la retranche mois par mois. Les deux se rejoignent sur un pourcentage, divergeraient sur un montant fixe. C'est le comportement de la version Flutter, reproduit tel quel.

**Relevé mensuel en PDF porté.** Même coque que le décompte annuel, tableau différent : `Prestation / Prix / Quantité / Montant`, les prestations regroupées par libellé de tarif. La quantité affiche « heures.minutes » pour un tarif horaire — **sans compléter les minutes par un zéro**, si bien que douze heures et cinq minutes s'écrivent « 12.5 » ; défaut conservé — et le nombre de prestations pour un tarif fixe. Seules les déductions de périodicité mensuelle s'appliquent.

Le filtre des lignes est `priceId != -1`, et non `priceId >= 0` comme pour le total du dossier enfant. Les deux coexistent dans la version Flutter et ne sont pas équivalents ; chacun est reproduit là où il se trouve.

**Triple recoupement sur juin 2026** : le brut du relevé mensuel (2363.00) égale la ligne « Juin 2026 » du décompte annuel, et son net (2120.32) égale la valeur « Juin » de la liste. Trois calculs indépendants qui concordent.

### Piège récurrent : lire le mauvais fichier

Trois fois dans la session, une fausse piste est née d'un chemin périmé ou ambigu. Le conteneur d'application change d'identifiant à chaque réinstallation. `UserDefaults` écrit sur disque de façon différée. Et surtout, **deux fichiers de préférences coexistent** pour une app de simulateur : celui du niveau appareil (`data/Library/Preferences/`) et celui du conteneur (`data/Containers/Data/Application/<id>/Library/Preferences/`). C'est le second que lit l'app. Un `find ... | head -1` tombe sur le premier.

`xcrun simctl spawn <appareil> defaults write` atteint bien le domaine de l'app, mais `defaults delete` n'a pas retiré les clés du conteneur. Pour remettre un encart d'aide, passer par « Réinitialiser les messages d'aide » du tiroir, qui est de toute façon le chemin qu'emprunte l'utilisatrice.

Ce piège a fait soupçonner à tort un encart d'aide qui ne s'affichait pas sur l'aperçu PDF. Il avait simplement été masqué par Yannick sur le simulateur, et l'app le gardait masqué — ce qui valide au passage la persistance : elle survit aux relances **et aux réinstallations**, le conteneur de données n'étant pas effacé.



Le relevé mensuel partage la coque du décompte annuel mais change de tableau : `Service / Prix / Quantité / Montant`, détaillé prestation par prestation, avec les heures affichées `h.mm` pour les tarifs horaires et un décompte pour les tarifs fixes. Il ne retient que les déductions de périodicité mensuelle, là où le décompte annuel les prend toutes. La requête correspondante reste à porter (`StatementViewCubit.loadStatement`).

### Reste à faire sur ces fondations

- `insertSampleData` (jeu de démonstration inséré à la première ouverture : tarifs, enfants, prestations, facture, réglages de facturation et logo) n'est pas porté. À traiter avec l'onboarding.
- Sur l'écran liste : le formulaire enfant (création et duplication) et la boîte de dialogue d'accueil ne sont pas portés — les boutons correspondants sont en place mais sans action.
- Les garde-fous d'archivage et de suppression sont couverts par `Tests/ChildFolderActionTests.swift`. La décision a été extraite de la vue dans `ChildFolderAction`, précisément pour pouvoir la vérifier : ce sont eux qui empêchent de supprimer un dossier portant des prestations et des factures. Le parcours complet (menu, boîte de confirmation, bandeau) n'a en revanche jamais été cliqué, bien que `cliclick` soit désormais disponible.

## Livraison : GitHub et Xcode Cloud

**Dépôt distant créé** : [ymauray/nannyplus.ios](https://github.com/ymauray/nannyplus.ios), public, sous GPL-3.0 comme le dépôt Flutter dont le portage dérive. Aucune donnée réelle n'est jamais entrée dans l'historique — ni base SQLite, ni PDF de relevé, ni plist de préférences, vérifié avant publication. Le tag `day_1` marque la fin de la première journée de portage.

**Trois obstacles rencontrés avant le premier build vert**, tous consignés ici parce qu'ils se reposeront :

1. **`Package.resolved` n'était pas versionné.** La règle `*.xcworkspace` du `.gitignore` écartait le dossier `project.xcworkspace` tout entier. Xcode Cloud compile avec la résolution automatique des paquets **désactivée** et s'arrête net sans ce fichier. La ré-inclusion visait jusque-là un fichier *à l'intérieur* du dossier exclu, ce que Git ignore : il ne descend pas dans un dossier écarté, il faut ré-inclure le dossier lui-même. GRDB est épinglé en 7.11.1. Vérifié au passage : `xcodegen generate` ne détruit pas ce fichier.

   À retenir : **GitHub Actions ne pouvait pas détecter ce problème**, compilant avec la résolution automatique activée. Les deux pipelines ne valident pas la même chose.

2. **Deux avertissements de concurrence stricte** sur `OpenURL`, appelant `UIApplication.shared.open` depuis un contexte `nonisolated`. Résolus par `@MainActor` sur l'enum — le seul appelant, le bouton d'appel de la tuile enfant, est déjà sur le fil principal. Ils existaient aussi en local, mais passaient inaperçus : les compilations ne filtraient que `error:`. **Filtrer aussi `warning:`.**

3. **Le train de version.** L'archive partait en `1.26.4 (196)`, soit le train de l'app Flutter en production. Le portage étant une réécriture, il ouvre le sien : `2.0.0`. Un build déposé dans l'ancien train aurait cohabité sur TestFlight avec la 1.26.4 (195) sous un libellé quasi identique, et y aurait enfermé le portage pour la suite.

**Le numéro de build vient d'Xcode Cloud, pas de `project.yml`.** Xcode Cloud tient un compteur (`$CI_BUILD_NUMBER`) mais ne l'écrit pas dans l'app : `ci_scripts/ci_post_clone.sh` le reporte dans `project.yml` avant `xcodegen generate`. Sans cela, chaque exécution reprendrait le même numéro et App Store Connect la rejetterait comme doublon — un numéro de build ne sert jamais deux fois sur un même train. L'injection a lieu **avant** la génération du projet, `CFBundleVersion` venant d'un build setting via `GENERATE_INFOPLIST_FILE` ; la faire plus tard obligerait à régénérer après la résolution des paquets. Le `"1"` inscrit dans `project.yml` n'est plus qu'une valeur de repli pour les compilations locales.

Première archive signée et livrée : **2.0.0 (3)**, les deux premiers numéros ayant été consommés par les essais de configuration.

## À revoir une fois le portage initial terminé

Points volontairement laissés de côté pendant le portage, à traiter après.

- **Cibles de déploiement iOS 26.0 / macOS 26.0** — reprises des `Podfile` Flutter. C'est restrictif pour une app grand public : à confirmer, et à abaisser si la valeur actuelle vient d'une mise à jour d'Xcode plutôt que d'un choix délibéré. Une ligne à changer dans `project.yml`.
- **Ordre de portage arrêté après discussion** : le menu Options d'abord (fait), puis « Paramètres de l'application ». Ce dernier ne contient que quatre champs, dont deux pilotent les notifications retirées. Son intérêt n'est pas de débloquer d'autres écrans — `AppPreferences` lit déjà tous les réglages et la liste des enfants les honore — mais de pouvoir enfin **faire varier** le tri et l'ordre d'affichage des noms, codés sans avoir jamais été éprouvés. Les six autres destinations sont des fonctionnalités à part entière, à porter dans l'ordre normal.
- **Deux incohérences de requête héritées de Flutter, reproduites telles quelles.** Elles fonctionnent aujourd'hui, mais reposent sur des propriétés des données actuelles plutôt que sur une règle explicite. À trancher une fois le portage terminé, c'est-à-dire à décider si l'on unifie ou si l'on documente l'intention.

  - **Filtre des prestations techniques.** Le total du dossier enfant écarte `priceId >= 0`, le relevé mensuel écarte `priceId != -1`. Les deux sélectionnent exactement les mêmes lignes dans la base réelle : les seules valeurs non positives sont 269 prestations à `priceId = -1`, toutes de total nul. **Leur origine reste à élucider** : Yannick ne se souvient pas de ce qui les crée, et aucun écran porté à ce jour n'en produit. Les deux filtres divergeraient dès qu'un `priceId` valant 0 apparaîtrait.
  - **Calcul du net avec une déduction à montant fixe.** La liste des relevés retranche le montant **mois par mois** ; le PDF le multiplie par le nombre de mois du décompte. Les deux coïncident sur un pourcentage, ce qui est le cas actuel — la base ne contient qu'une déduction, en pourcentage. Une déduction à montant fixe les ferait diverger, et il faudrait alors savoir laquelle a raison.

- **Nettoyage de la base de données** — il y a du ménage à faire dans les données existantes. Yannick doit d'abord étudier ce qui est concerné ; à ne pas entreprendre avant cette analyse, et surtout pas pendant le portage, pour que les deux versions restent comparables sur des données identiques.

## Prochaine étape

Rien n'est arrêté. Trois directions se valent :

- **Les trois plannings** du menu Options, qui achèveraient ce menu. Deux sont des PDF, et le générateur de relevés donne déjà le canevas.
- **Le contenu du dossier enfant**, dont seule la coque existe : saisie des prestations, liste des factures, édition des informations. C'est le cœur de l'usage quotidien.
- **La facturation**, le morceau le plus exposé avec les PDF de relevés, puisque la facture part chez les parents. Elle englobe la relance par SMS, dont le gabarit est déjà porté dans les paramètres.

Demander à Yannick une capture de l'écran visé avant de commencer, selon la méthode convenue.
