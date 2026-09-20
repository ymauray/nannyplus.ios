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
| Dossier enfant — onglet Prestations | **fait**, saisie comprise |
| Dossier enfant — onglet Factures | **fait**, création comprise |
| Dossier enfant — onglet Information | **fait**, planning de l'enfant compris |
| Options — menu | **fait** |
| Options — Tarifs | **fait** : lecture, création, modification, suppression, réordonnancement |
| Options — Déductions | **fait**, idem |
| Options — Paramètres de l'application | **fait** |
| Options — Paramètres de la facture | **fait** |
| Options — Relevés | **fait** : liste, décompte annuel et relevé mensuel en PDF |
| Options — Planning hebdomadaire | **fait** : PDF recoupé au pixel avec la référence |
| Options — Planning annuel | **fait** : PDF recoupé au pixel, sélecteur d'année compris |
| Options — Planning des congés | **fait** : saisie, bascule, suppression, tri |
| Formulaire enfant | à porter |
| Saisie des prestations | à porter |
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
  xcrun simctl terminate <appareil> ch.yannickmauray.nannyplusios
  cp ~/Library/Containers/ch.frenchguy.nannyplus/Data/Documents/childcare.db \
     "$(xcrun simctl get_app_container <appareil> ch.yannickmauray.nannyplusios data)/Documents/"
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

**Planning hebdomadaire porté** (`Sources/Shared/Features/WeeklySchedule/`, `Schedule.swift`, `ScheduleRepository.swift`). Une page A4 **paysage** : cinq jours en colonnes, une sous-colonne par enfant repérée par ses initiales, douze rangs d'une heure de 07:00 à 18:00 découpés en quarts d'heure. Un quart est peint de la couleur de l'enfant dès qu'un créneau le couvre — début inclus, fin exclue.

La référence n'était pas une capture d'écran mais le PDF produit par la version Flutter, ce qui a permis d'aller plus loin qu'à l'accoutumée : **le flux de contenu du document a été décompressé et lu opérateur par opérateur**, donnant la géométrie exacte plutôt que déduite. Tout en découle.

- Marge de 16 points, titre en Helvetica 12, un `SizedBox` de 38 points, deux demi-rangs d'en-tête de 19 points, puis douze rangs de 38.
- **Les hauteurs de texte viennent des métriques AFM d'Helvetica**, pas d'UIKit : le paquet `pdf` compose une ligne à 0,931 + 0,225 cadratin et pose la base à l'ascendante. Le texte est donc dessiné par Core Text à une ligne de base explicite, seule façon de retrouver les mêmes ordonnées.
- **Le crénage est désactivé** (`.kern: 0`). Core Text l'applique d'office, le paquet `pdf` enchaîne les chasses sans lui : sans ce zéro, « Vendredi » et « AC » se resserrent d'un tiers de point. C'est la seule correction qu'a demandée la comparaison.
- Les données sont lues sans filtre : `readPeriods` prend toutes les lignes de `periods`, `planningId` compris, exactement comme côté Flutter. Les enfants retenus sont ceux qui ont au moins un créneau, **ordonnés par la liste des dossiers** — donc soumis aux réglages de tri et d'affichage des noms, et privés des archivés.

**Un défaut reproduit à dessein** : les cellules sont peintes après les filets verticaux qui les précèdent, et les recouvrent de moitié. Tous les traits verticaux font donc un demi-point, sauf le dernier — seul à n'être suivi d'aucune cellule — qui en fait un. Même chose pour les filets horizontaux, pleins dans la colonne des heures et deux fois plus fins dans la grille. C'est le fruit de l'ordre de dessin de Flutter, et l'ordre a été repris tel quel.

**Contrôle au pixel** : les deux PDF rendus à 2400 points de large ne diffèrent que sur **130 pixels de 4 070 400**, soit 0,003 %, tous dans les initiales « AC » d'une seule colonne — un reste de pavage de glyphe. Les 1200 cellules, les 95 filets et toutes les autres chaînes se superposent exactement. Les couleurs, relevées dans `schedule_colors`, sont identiques au bit près, et le décompte des cases peintes recoupe la base enfant par enfant : 91 pour Elaïa, 96 pour Maé, 64 pour Willow, 38 pour Amély, 28 pour Zoé.

L'écran d'aperçu était déjà écrit : `StatementPreviewView` devient **`PdfPreviewView`** (`Sources/Shared/Features/Shell/`), partagé entre les relevés et le planning, avec un encart d'aide devenu facultatif — le planning n'en a pas, côté Flutter comme ici. Le fichier partagé s'appelle `planning_hebdomadaire.pdf`, là où Flutter propose `schedule.pdf` ; c'est la même francisation que pour les relevés.

`Tests/WeeklyScheduleTests.swift` couvre la règle de couverture d'un quart d'heure, le filtrage par jour, le repli en violet d'un enfant sans couleur, et le format de la page.

**Planning annuel porté** (`Sources/Shared/Features/YearlySchedule/`, `VacationPeriod.swift`, `VacationPeriodRepository.swift`). Une page A4 paysage de plus : douze colonnes de mois, chacune avec son en-tête gris, une ligne d'initiales, puis un rang par jour portant le quantième, la lettre du jour et une case par enfant coupée en deux — matin en haut, après-midi en bas. Les congés grisent la case entière, le week-end la laisse vide.

Même méthode que l'hebdomadaire : flux de contenu du PDF de référence décompressé et lu opérateur par opérateur. La géométrie en découle — rang de 15 points, quantième dans un carré de 15, lettre du jour dans les trois quarts, colonne de mois à 67,49 points, en-tête de 26,71 points de haut (le texte plus deux fois 8 de marge).

**Trois défauts reproduits, tous invisibles à la lecture rapide du Dart** :

- **Un créneau est classé sur sa seule heure de début.** Une garde de 8:00 à 17:45 ne marque que le matin, et laisse l'après-midi blanc.
- **Les congés sont filtrés sur leur date de début seule** (`start LIKE '2026%'`). Une période à cheval sur le Nouvel An n'appartient qu'à l'année où elle commence : celle du 21 décembre au 1er janvier grise bien la fin décembre, mais rien en janvier de l'année suivante.
- **Les initiales trop larges se coupent lettre par lettre.** « WG » déborde d'une colonne de 8,25 points à cinq enfants et passe sur deux lignes — et une chaîne coupée remplit la largeur, si bien que le centrage n'a plus de prise et que les deux lettres s'alignent à gauche.

**Contrôle au pixel** : les deux PDF rendus à 2400 points de large diffèrent sur **56 pixels sur 4 070 400**, soit 0,001 %, tous sur la dernière lettre de « Juillet » et de « Novembre » — un pixel de pavage de glyphe. Les douze en-têtes se posent aux mêmes abscisses au centième, et l'intégralité de la grille, jours, gris de week-end, gris de congés et demi-cases de couleur, se superpose exactement.

**Le bandeau incurvé porte le sélecteur d'année** : une flèche de chaque côté, et l'année elle-même qui ramène à l'année en cours quand on la touche — les trois contrôles de la version Flutter, avec la même conséquence, le document se recomposant à chaque changement. Vérifié sur simulateur : 2026 et 2025 affichent chacun leurs congés et leurs jours de semaine.

**`PdfText` factorise la composition** (`Sources/Shared/Design/PdfText.swift`) : métriques AFM, crénage neutralisé, coupure lettre par lettre, dessin sur une ligne de base explicite. Les deux générateurs s'appuient dessus, et le contrôle au pixel de l'hebdomadaire a été rejoué après la bascule — au pixel près le même résultat qu'avant. `PdfPreviewView` accepte désormais un contenu de bandeau quelconque, un simple libellé pour les relevés et l'hebdomadaire, le sélecteur d'année pour l'annuel.

`Tests/YearlyScheduleTests.swift` couvre l'appartenance à une période de congés, le classement matin/après-midi, la coupure des initiales et le format de la page.

**Planning des congés porté** (`Sources/Shared/Features/VacationPlanning/`). Une carte par période de l'année, dans l'ordre où la base les rend. L'interrupteur bascule entre une journée isolée et une période, les crayons ouvrent un sélecteur de date, la croix supprime **sans confirmation** — contrairement au reste de l'app, et comme côté Flutter.

Les règles de saisie sont sorties de la vue dans `VacationPeriodEdit`, comme `ChildFolderAction` avant elles, pour être vérifiables :

- Pousser le début au-delà de la fin **emmène la fin avec lui** ; poser une fin avant le début **tire le début avec elle**.
- Allumer l'interrupteur ouvre la période sur son propre jour de début ; l'éteindre la referme sur une journée isolée.
- Le tri classe par date de début puis de fin, une journée isolée passant avant une période qui commence le même jour, et renumérote les `sortOrder`. Flutter l'appelle en quittant l'écran et à chaque changement d'année par les flèches, **mais pas quand on touche l'année** pour revenir à l'année en cours. Incohérence conservée.

**Le bouton « + » ne demande rien** : il crée une journée isolée à la dernière date connue — le 1er janvier tant que la liste est vide, sinon la plus tardive des dates affichées, **fins comprises**. Sur la base réelle, la dernière période de 2026 s'achevant le 1er janvier 2027, ajouter un congé depuis 2026 le crée en 2027, où il disparaît aussitôt de la liste. Vérifié sur simulateur : le congé atterrit bien au 1er janvier 2027 avec un `sortOrder` de 9999.

*Écart* : côté Flutter cette dernière date se construit **au fil du défilement**, la liste étant paresseuse ; ajouter sans avoir déroulé jusqu'en bas retient une date plus ancienne. On prend ici toutes les périodes de l'année, c'est-à-dire ce que Flutter fait une fois la liste parcourue.

Le `showDatePicker` de Material devient une feuille portant un `DatePicker` graphique, avec Annuler et OK — le calendrier du système, et la date retenue seulement si on valide, comme la boîte de dialogue Material. Bornes identiques : du 1er janvier de l'an dernier au 1er janvier dans dix ans.

**Les quatre gestes éprouvés sur simulateur**, base réelle à l'appui : le crayon déplace le début du 1er au 5 janvier et la fin suit ; « + » crée la journée là où il est dit ci-dessus ; l'interrupteur ouvre puis referme la période ; la croix supprime la ligne. Chaque effet a été recoupé dans la base, et l'état de départ restitué.

**Onglet Prestations porté** (`Sources/Shared/Features/ChildDetail/ServiceListTabView.swift`, `Service.swift`). Une carte par journée, la plus récente en haut : la date, une corbeille qui supprime la journée entière après confirmation, le détail de chaque prestation, puis le total du jour. Recoupé avec la référence sur le dossier de Rafa Dicembrino — mêmes dates, mêmes libellés, mêmes durées, 24.00, 41.00 et 28.00 pour 93.00 au bandeau.

L'ordre demande deux passes, comme côté Flutter : les prestations non facturées sont lues par date décroissante, puis **triées selon l'ordre de la grille tarifaire**, ce qui détermine leur rang à l'intérieur d'une journée ; le regroupement par date rétablit ensuite l'ordre chronologique inverse entre les cartes. Les tarifs techniques (`priceId < 0`) sont écartés.

**Un plantage latent évité.** `loadServices` classe les prestations par `prices.firstWhere(...)` : une prestation dont le tarif a été supprimé — et la suppression est physique — ferait lever une exception et viderait l'onglet sur « Erreur lors du chargement des prestations ». On classe ces lignes en fin de liste. Aucune n'existe dans la base réelle aujourd'hui.

**`FlexRow` remplace ce que `layoutPriority` ne sait pas faire** (`Sources/Shared/Features/Shell/FlexRow.swift`). SwiftUI n'a pas de flex : `layoutPriority` change l'ordre d'attribution de l'espace, pas les proportions, et la première tentative donnait des cartes démesurées avec la colonne des montants hors champ. `FlexRow` est un `Layout` qui distribue la largeur au prorata de poids, les vues de poids nul gardant leur largeur naturelle — les `SizedBox` intercalés de Flutter. Il sert aux colonnes du détail et au filet court au-dessus du total.

Les proportions sont celles du Dart, et elles **ne s'accordent pas entre les deux formes** : 2/2/1 pour un tarif horaire, 5/1 pour un tarif fixe, la colonne du détail disparaissant avec lui. Seul le bord droit reste aligné. Défaut conservé.

**Deux pièges de SwiftUI relevés au passage** : un `Divider` placé dans un `HStack` devient un séparateur *vertical* et étire toute la carte — d'où `MaterialDivider`, un filet explicite de 1 point en noir à 12 %, centré dans une boîte de 2 comme le `Divider(height: 2)` de Material.

**La barre d'onglets de la coque était trop haute de 12 points**, et tout l'écran avec elle. Le `maxExtent` du sliver vaut `tabBar.preferredSize.height`, soit 48 **marge du bas comprise** : la barre est donc comprimée à 36 points, et non posée sur 48 puis complétée par 12. Corrigé. Après quoi le trait d'onglet tombe à 209,0 contre 209,1 sur la référence, et le haut de la première carte à 231,0 contre 230,8.

### Poppins compose plus serré qu'en Flutter

Une dérive subsiste, et elle dépasse cet écran. Les positions d'encre concordent au dixième de point sur la première carte, puis chaque carte se raccourcit : les trois dates de référence tombent à 245,7, 380,2 et 543,3, les nôtres à 245,3, 376,3 et 534,3 — soit −0,4, −3,9 puis −9,0 points.

La cause est typographique. **Les fichiers Poppins déclarent une hauteur de ligne de 1,5 cadratin** (`hhea` comme `typo`, `USE_TYPO_METRICS` armé), soit 21,00 points à 14 et 24,00 à 16. Flutter s'y tient ; UIKit compose sur environ 1,41 cadratin, et perd donc à peu près 1,2 point par ligne. L'écart est invisible sur une ligne isolée et s'additionne dès qu'on empile des cartes.

L'écran de saisie l'illustre plus nettement encore, ses cartes étant courtes et nombreuses : deux lignes chacune, donc 2,4 points perdus par carte, et **11,8 points d'écart dès la quatrième**. Les hauteurs d'encre, elles, concordent — 10,2 contre 10,4 points pour un titre — ce qui confirme que la taille des polices est juste et que seul le pas des lignes diffère.

**C'est un fait global, pas un défaut de cet écran** : il vaut pour chaque texte de l'app, y compris les écrans déjà validés — leurs contrôles portaient sur des positions d'encre, qui ne le révèlent pas. Rien n'est fait pour l'instant : le point est porté aux choses à revoir une fois le portage terminé.

**Saisie des prestations portée** (`ServiceFormView.swift`, `TimeInputDialog.swift`). Une modale plein écran à deux onglets pour une même journée : la grille tarifaire, où un « + » ajoute le tarif au jour actif, et les prestations déjà ajoutées à ce jour, avec leur compte dans le libellé de l'onglet. Le calendrier de la barre de titre change de jour — du 1er janvier de l'an dernier au 1er janvier de l'an prochain, fourchette plus courte que celle du planning des congés.

Le bouton flottant ouvre la saisie sur aujourd'hui et sur l'onglet des tarifs ; toucher une carte de journée l'ouvre sur cette journée et sur l'onglet des prestations ajoutées, et le titre passe alors de « Ajouter une prestation » à « Modifier une prestation ».

- **Un tarif fixe s'ajoute sans rien demander** ; un tarif horaire ouvre `TimeInputDialog`, deux menus déroulants — heures de 0 à 12, minutes par quarts — et un bouton « Enregistrer ». La boîte est blanche, à angles droits, posée sur un voile : c'est un `Dialog` de Material, pas une feuille venue du bas.
- **Aucun champ n'est obligatoire** : valider sans rien choisir renvoie 0h00, que l'appelant traite comme une saisie annulée et signale par « Saisie annulée ». Défaut conservé.
- Seule une prestation horaire se modifie, un tarif fixe n'ayant pas de durée. La suppression demande confirmation, contrairement à celle du planning des congés.
- **L'ajout ramène sur l'onglet des tarifs**, la suppression sur celui des prestations ajoutées : c'est l'onglet que `loadRecentServices` reçoit en argument dans chaque cas.

**Du code mort non porté** : le cubit calcule une liste `services` de prestations récentes, groupées par tarif, que la vue ne lit jamais. Avec elle disparaît `getRecentServices`.

**Les six gestes éprouvés sur simulateur**, base réelle à l'appui et état de départ restitué : ajout d'un tarif fixe (« Petit repas » à 5.00), ajout d'un tarif horaire (2h30 × 8.00 = 20.00 en base), bascule vers l'onglet « Ajoutées (2) », ouverture du crayon qui retrouve bien 2 et 30, confirmation de suppression, et rechargement de la liste des journées à la fermeture.

**Une icône sans équivalent** : `Icons.edit_calendar` — un calendrier frappé d'un crayon — n'a pas de symbole SF correspondant. On affiche un simple `calendar`. C'est l'approximation la plus faible du lot, avec celle du planning hebdomadaire.

**Onglet Factures porté** (`Sources/Shared/Features/ChildDetail/InvoiceListTabView.swift`, `Invoice.swift`). Une carte par année, la plus récente en haut : l'année, la moyenne d'une facture sur l'année, un bouton PDF, puis une ligne par facture. Sous la liste, un bouton montre ou masque les factures payées ; sans facture ouverte, une carte annonce « Aucune facture ouverte trouvée ».

- **Une facture payée s'écrit en italique, une facture en retard en rouge.** Le retard se mesure au délai des paramètres de l'application, dix jours par défaut. Le style est `bodyLarge`, soit Poppins Medium 14 ; l'italique retombe sur la graisse normale, seule fonte italique embarquée.
- **La moyenne ignore le filtre** : elle porte sur toutes les factures de l'année, payées comprises, alors que la liste n'en montre qu'une partie. Recoupé sur la référence — 636.13 en 2026, 285.68 en 2025.
- **Supprimer une facture rend ses prestations à facturer** plutôt que de les supprimer avec elle, d'où le rechargement du bandeau et de l'onglet des prestations.
- Le menu d'une ligne reprend les trois entrées de Flutter, « Marquer comme payée » et « Supprimer » étant désactivées sur une facture déjà payée.

L'onglet est désormais complet.

**Vérifié sur simulateur** contre la référence : l'écart de position des huit lignes de 2026 va de 0,8 à 1,3 point, sans s'accumuler. Le cas des impayées, dont il n'existe pas de capture, a été éprouvé en désarchivant provisoirement un dossier qui en porte douze : les lignes sortent bien en rouge et sans italique. Le marquage d'une facture comme payée a été mené jusqu'en base puis défait, le dossier réarchivé.

**Deux défauts de mise en page corrigés au passage.** Un `.padding(.bottom, 8)` posé sur un `ForEach` s'applique à **chaque** élément et non une fois en bas : les rangs faisaient 64 points au lieu de 56, et l'écart s'accumulait de carte en carte. Et `FlexRow` alignait ses enfants en haut, là où une `Row` de Flutter les centre sur l'axe transversal.

### L'arrondi des montants

`toStringAsFixed(2)` de Dart arrondit la moitié **vers le haut** ; `String(format: "%.2f")` l'arrondit vers le **pair le plus proche**. Une moyenne de 636,125 s'écrivait donc « 636.12 » chez nous et « 636.13 » sur la référence. Corrigé dans `twoDecimals`, en arrondissant la valeur multipliée par cent.

Reste un écart de principe, jugé sans conséquence : Dart arrondit la valeur binaire exacte du nombre, nous sa valeur multipliée par cent. Une valeur qui n'est qu'approximativement une moitié — 2,675 vaut en réalité 2,67499… — remonte ici à 2.68 quand Dart descend à 2.67. Aucun montant réel n'est dans ce cas, les moitiés exactes venant des moyennes.

**Planning de l'enfant porté** (`ChildScheduleView.swift`). Le crayon de la première carte de la fiche ouvre l'écran : la couleur de l'enfant dans les plannings, puis un créneau par carte — le jour, l'heure de début, l'heure de fin, et de quoi dupliquer ou supprimer. Le « + » de la barre de titre ajoute un créneau sans jour, de 7:00 à 18:00.

- **Le tri a lieu à la fermeture**, pas à chaque changement : les créneaux se renumérotent par jour, puis par heure de début, puis de fin. Un créneau sans jour passe en dernier, et la liste s'affiche entre-temps dans l'ordre où elle a été laissée.
- **Lire la couleur d'un enfant la crée** : un dossier qui n'en a pas s'en voit attribuer une, violette, enregistrée aussitôt. Défaut conservé.
- La boîte de saisie des heures est celle des prestations, avec une autre plage : de 7 à 19 heures ici, de 0 à 12 là-bas, puisqu'on saisit une heure de la journée et non une durée.
- **Samedi et dimanche ne sont pas proposés** par le menu des jours, alors que la base les accepte et que le tri sait les classer.

**Deux substitutions natives** : le choix de couleur passe du nuancier Material de `flex_color_picker` à celui du système, et `ColorIndicator` devient un simple rectangle de 40 points, sa hauteur par défaut.

**Vérifié sur simulateur** contre la référence, puis en base : le « + » crée bien un créneau sans jour de 7:00 à 18:00 en fin de liste, et la croix le retire. Deux corrections de mise en page au passage — les heures passaient à la ligne faute de `fixedSize`, et le rectangle de couleur faisait 60 points au lieu de 40.

**Onglet Information porté** (`ChildInfoTabView.swift`, `Document.swift`). Une carte par information : un libellé en petit, la valeur en gras dessous, et parfois une commande à droite. La photo de profil coiffe la liste quand le dossier en porte une ; les téléphones secondaires et le texte libre n'apparaissent que s'ils sont remplis.

- **La réserve d'heures se règle ici**, par deux boutons qui écrivent aussitôt en base. Rien n'empêche de descendre sous zéro, comme côté Flutter.
- **Les documents montrent où ils se trouvent** : un cylindre vert pour ceux rangés dans la base, une coche verte pour un fichier retrouvé sur le disque, un point d'exclamation rouge sinon. C'est le défaut que les SPECS annonçaient — deux générations de code coexistent, et la base réelle en porte cinq de l'ancienne et trois de la nouvelle. Les toucher ouvre le document dans le visualiseur du système, l'équivalent d'`OpenFile`.
- **« Pas d'allergie connue » ne remplace qu'un champ nul**, pas un champ vidé : un dossier dont on a effacé les allergies affiche une carte sans valeur. Défaut conservé.

**Vérifié sur simulateur** contre la référence : les sept cartes de Zoé Mauray tombent à 4 points près au départ, l'écart se réduisant ensuite — c'est la hauteur de ligne de Poppins, déjà au carnet. La réserve d'heures a été montée puis redescendue jusqu'en base, et le PDF d'une convention rangée en base s'est ouvert en aperçu.

**`FrenchDate` factorise le format de date** (`Sources/Shared/Design/FrenchDate.swift`). Les deux formateurs — celui de la base et celui que lit l'utilisatrice — existaient en quatre exemplaires, dans les deux onglets, le PDF de facture et cette fiche.

**Création d'une facture portée** (`InvoiceFormView.swift`). Deux cartes : celle du haut nomme l'enfant du dossier et laisse choisir le mois, celle du bas coche les autres enfants à joindre au même document. Une disquette dans la barre de titre enregistre.

Ce que fait l'enregistrement, repris pas à pas : une facture est créée au numéro suivant, datée du jour, avec le nom des parents et l'adresse **de l'enfant du dossier** ; puis, pour chaque enfant retenu, un marqueur est ajouté et ses prestations du mois choisi sont rattachées à la facture et marquées facturées ; le total est la somme de ce qui a été rattaché, et les crédits d'heures s'écrivent « Maé: 0, Ellie: 0 ».

**Trois défauts conservés :**

- **Le sélecteur propose les mois de tous les enfants**, pas seulement ceux du dossier ouvert. On peut donc retenir un mois où l'enfant du dossier n'a rien, et produire une facture qui ne porte que ses marqueurs, pour un total nul.
- **Le contrôle « y a-t-il quelque chose à facturer » porte sur toutes les prestations non facturées**, pas sur celles du mois retenu. C'est ce qui rend le cas ci-dessus possible.
- **Le mois retenu d'office est le plus ancien**, la liste étant triée par ordre croissant.

Deux plantages évités : le nom des parents et l'adresse sont déréférencés de force côté Flutter, et manquent parfois ; on prend la chaîne vide.

**Vérifié en base** sur le dossier de Maé, puis défait : facture n° 284 datée du jour, total 1281.00, crédits « Maé: 0 », la prestation du 1er septembre rattachée et marquée facturée, et le marqueur créé avec elle.

**Une mesure utile** : un `DropdownButton` de Material n'est jamais plus court que la hauteur tactile minimale. Sans ce plancher de 48 points, le rang se tassait et tout l'écran remontait de 12 points. Après quoi les positions concordent à 2 points près sur les neuf premières lignes, sans dérive.

**Relance par SMS portée** (`InvoiceNotification.swift`). L'entrée « Notifier » du menu d'une facture ouvre Messages avec le destinataire et le texte déjà remplis ; l'app ne dessine rien d'autre que le bandeau qui dit si elle y est parvenue. Le gabarit vient des paramètres de la facture, `{{date}}` et `{{total}}` remplacés, et le numéro est débarrassé de tout ce qui n'est ni chiffre, ni point, ni tiret, ni plus — les libellés que l'utilisatrice y met.

L'adresse prend la forme `sms:<numéro>&body=<message>`, l'esperluette étant ce qu'attend iOS là où Android prend un point d'interrogation.

**Un écart technique nécessaire** : le message est encodé, ce que Flutter ne fait pas — il assemble l'adresse par interpolation et la confie telle quelle à `Uri.parse`. Sans encodage, `URL(string:)` refuse la moindre espace, et le gabarit par défaut en compte une trentaine. L'encodage couvre aussi `&` et `=`, pour qu'un gabarit qui en contiendrait ne coupe pas l'adresse en deux.

**Un plantage évité** : côté Flutter, un dossier sans numéro déréférence `child.phoneNumber!` et fait tomber l'écran. On signale l'échec à la place. « Impossible d'ouvrir l'application de SMS » est par ailleurs écrit en français, `fr.po` ne traduisant pas ce message.

Vérifié sur simulateur : toucher « Notifier » bascule bien sur Messages, la barre d'état affichant le retour vers Nanny+.

**Les deux PDF de facturation portés** (`Sources/Shared/Features/Invoices/`). La facture qu'ouvre un appui sur une ligne, et le relevé annuel de l'enfant qu'ouvre le bouton PDF d'une année. Tous deux en A4 portrait, marge 50, en-tête dans les polices des réglages de facture, logo ancré en haut à droite.

Les deux documents sont bâtis sur les mêmes widgets côté Flutter, au point que leurs fonctions se recopient l'une l'autre ; `InvoiceDocument` ne les écrit qu'une fois — page, en-tête, cartouche, intitulés bleus, tableau, pied de page.

**Le tableau reprend la mise en page d'un `pw.Table`** dont toutes les colonnes sont en `IntrinsicColumnWidth` sans flex. L'algorithme est simple une fois lu dans le paquet : la largeur intrinsèque de chaque colonne — la plus large de ses cellules — est **mise à l'échelle pour remplir la largeur disponible**, les proportions étant conservées. Rien à deviner, donc, et les colonnes tombent d'elles-mêmes aux bons endroits.

**Trois détails qui ne se lisaient que dans la mesure** :

- Les intitulés bleus du bloc méta sont des textes nus, sans la marge de 6 points que porte l'intitulé d'une colonne. La différence se voyait à 6 points par ligne, trois fois de suite.
- L'écart entre un intitulé et sa valeur tient compte de la différence d'ascendante entre Helvetica-Bold et Helvetica, 0,43 point à 14.
- Le total du relevé vit dans une `Row` dont un `SizedBox` fixe la hauteur à 70 points : l'alignement transversal le **centre** dans cette bande, il ne se pose pas en haut.

**Contrôle au pixel**, logo exclu — celui du simulateur n'est pas celui du téléphone de Yannick : **505 pixels de différence sur 1 809 600 pour la facture**, soit 0,03 %, et **748 pour le relevé**, soit 0,04 %. Ce qui reste tient aux bords du cadre du titre et à quelques arêtes de glyphes.

**Pagination de la facture reproduite** : quatorze unités de hauteur sur la première page, trente sur les suivantes, une unité et demie par journée plus une par prestation, et une page vide de plus si le pied de page n'a plus la place de tenir. Couverte par un test.

### Ce que sont les prestations à `priceId = -1`

La question traînait depuis le portage des relevés ; les documents de facturation y répondent. **Ce sont des marqueurs qui rattachent un enfant à une facture** : libellé vide, total nul, et une ligne par enfant concerné. Une facture peut en effet couvrir **plusieurs enfants**, pour regrouper une fratrie sur un seul document.

La base en compte 269, réparties sur 212 factures — une seule pour la plupart, jusqu'à six pour l'une d'elles — et 42 factures couvrent plus d'un enfant.

Les deux documents s'en servent différemment, et c'est ce qui les rend visibles :

- **La facture** compose son titre à partir de *tous* les enfants de ses prestations, marqueurs compris — d'où « Maé et Ellie » —, puis **filtre les marqueurs** pour dresser son tableau, qui ne montre donc qu'une ligne.
- **Le relevé d'un enfant** ne filtre rien : chaque enfant de la facture y gagne sa ligne, avec la somme de ses prestations. Un enfant qui n'a qu'un marqueur sort donc à 0.00 en face d'une facture pourtant payée.

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

4. **Une erreur de concurrence que seul Xcode Cloud voyait.** `statements` sortait des `Row` de GRDB de son bloc de lecture ; `Row` est explicitement non-`Sendable`, et franchir la frontière d'isolation avec elle est une erreur. La conversion se fait désormais à l'intérieur du bloc, vers une petite structure `Sendable`. Les quatre autres requêtes qui manipulent des `Row` consommaient déjà les leurs sur place.

   À retenir : **la compilation locale et GitHub Actions passaient toutes les deux**, avec Xcode 26.6 et Swift 6.3.3. Xcode Cloud compile avec un toolchain plus récent, qui applique la concurrence stricte plus complètement. C'est la deuxième asymétrie entre les pipelines après celle de `Package.resolved`, et elle va dans l'autre sens : ici c'est Xcode Cloud qui est le plus sévère.

**Le numéro de build vient d'Xcode Cloud, pas de `project.yml`.** Xcode Cloud tient un compteur (`$CI_BUILD_NUMBER`) mais ne l'écrit pas dans l'app : `ci_scripts/ci_post_clone.sh` le reporte dans `project.yml` avant `xcodegen generate`. Sans cela, chaque exécution reprendrait le même numéro et App Store Connect la rejetterait comme doublon — un numéro de build ne sert jamais deux fois sur un même train. L'injection a lieu **avant** la génération du projet, `CFBundleVersion` venant d'un build setting via `GENERATE_INFOPLIST_FILE` ; la faire plus tard obligerait à régénérer après la résolution des paquets. Le `"1"` inscrit dans `project.yml` n'est plus qu'une valeur de repli pour les compilations locales.

Première archive signée et livrée : **2.0.0 (3)**, les deux premiers numéros ayant été consommés par les essais de configuration.

## À revoir une fois le portage initial terminé

Points volontairement laissés de côté pendant le portage, à traiter après.

- **Cibles de déploiement iOS 26.0 / macOS 26.0** — reprises des `Podfile` Flutter. C'est restrictif pour une app grand public : à confirmer, et à abaisser si la valeur actuelle vient d'une mise à jour d'Xcode plutôt que d'un choix délibéré. Une ligne à changer dans `project.yml`.
- **Ordre de portage arrêté après discussion** : le menu Options d'abord (fait), puis « Paramètres de l'application ». Ce dernier ne contient que quatre champs, dont deux pilotent les notifications retirées. Son intérêt n'est pas de débloquer d'autres écrans — `AppPreferences` lit déjà tous les réglages et la liste des enfants les honore — mais de pouvoir enfin **faire varier** le tri et l'ordre d'affichage des noms, codés sans avoir jamais été éprouvés. Les six autres destinations sont des fonctionnalités à part entière, à porter dans l'ordre normal.
- **Deux incohérences de requête héritées de Flutter, reproduites telles quelles.** Elles fonctionnent aujourd'hui, mais reposent sur des propriétés des données actuelles plutôt que sur une règle explicite. À trancher une fois le portage terminé, c'est-à-dire à décider si l'on unifie ou si l'on documente l'intention.

  - **Filtre des prestations techniques.** Le total du dossier enfant écarte `priceId >= 0`, le relevé mensuel écarte `priceId != -1`. Les deux sélectionnent exactement les mêmes lignes dans la base réelle : les seules valeurs non positives sont 269 prestations à `priceId = -1`, toutes de total nul. Les deux filtres divergeraient dès qu'un `priceId` valant 0 apparaîtrait. *(Leur origine, elle, n'est plus un mystère — voir ci-dessous.)*
  - **Calcul du net avec une déduction à montant fixe.** La liste des relevés retranche le montant **mois par mois** ; le PDF le multiplie par le nombre de mois du décompte. Les deux coïncident sur un pourcentage, ce qui est le cas actuel — la base ne contient qu'une déduction, en pourcentage. Une déduction à montant fixe les ferait diverger, et il faudrait alors savoir laquelle a raison.

- **Revenir au bundle identifier et à l'icône de production.** Le portage porte depuis le 20 septembre 2026 l'identifiant `ch.yannickmauray.nannyplusios` et une icône violette, pour que sa build TestFlight cohabite avec la 1.26.4 au lieu de la remplacer, et qu'on distingue les deux sur le téléphone. **Les deux changements sont à défaire avant la mise en production** : reprendre `ch.frenchguy.nannyplus` dans `project.yml`, et remettre l'icône bleue mise de côté dans [`icone-production/`](icone-production/).

  Tant que l'identifiant diffère, **le conteneur diffère aussi** : la version native n'ouvre pas la base de l'app Flutter mais la sienne, et ne reprend donc plus les données toute seule — il faut passer par une sauvegarde puis une restauration. Reprendre l'identifiant d'origine rendra la base existante visible sans import, le chemin étant resté le même. Côté App Store Connect, l'identifiant provisoire demande une fiche d'app distincte, avec son propre compteur de builds, et un profil de provisionnement qui le couvre.
- **La hauteur de ligne de Poppins.** Les fichiers de police déclarent 1,5 cadratin, Flutter s'y tient, UIKit compose sur environ 1,41 : chaque ligne de texte perd à peu près 1,2 point, et l'écart s'additionne dès qu'on empile des cartes — 11,8 points à la quatrième carte de la saisie de prestations. Les tailles de police, elles, sont justes : les hauteurs d'encre concordent. Le corriger suppose d'imposer la boîte de ligne à chaque texte, donc de reprendre tous les écrans déjà validés ; c'est un chantier à part, à mener d'un coup plutôt qu'écran par écran. Le détail est dans « Poppins compose plus serré qu'en Flutter » ci-dessus.
- **La saisie des congés est à revoir.** Le bouton « + » ne demande rien : il crée une journée à la dernière date connue, qu'il faut ensuite corriger au crayon, et qui peut atterrir dans une autre année que celle affichée. Reproduit à l'identique pour l'instant, sur décision de Yannick, mais l'écran mérite un vrai formulaire — choisir la ou les dates avant de créer, plutôt qu'après.
- **Nettoyage de la base de données** — il y a du ménage à faire dans les données existantes. Yannick doit d'abord étudier ce qui est concerné ; à ne pas entreprendre avant cette analyse, et surtout pas pendant le portage, pour que les deux versions restent comparables sur des données identiques.

## Prochaine étape

Le menu Options est **entièrement porté**. Restent deux blocs, et ils se valent :

- **La facturation**, le morceau le plus exposé avec les PDF de relevés, puisque la facture part chez les parents : création d'une facture, PDF de la facture, décompte annuel de l'enfant, et relance par SMS dont le gabarit est déjà porté dans les paramètres.
- **L'onglet Information du dossier enfant**, dernier des trois à rester une maquette, et le formulaire enfant qui va avec.

Demander à Yannick une capture de l'écran visé avant de commencer, selon la méthode convenue.
