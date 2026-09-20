# Nanny+ — version native iOS

Portage 1:1 de l'app Flutter [Nanny+](https://apps.apple.com/fr/app/nanny/id1602676918),
une app de gestion pour nounous indépendantes : dossiers enfants, suivi des
prestations, facturation PDF, relevés, planning. Aucune donnée ne quitte
l'appareil.

L'objectif est une réplique fidèle de l'app Flutter existante, défauts
d'ergonomie compris, et non une amélioration.

- [`AGENTS.md`](AGENTS.md) — les consignes de travail, à lire en premier
- [`SPECS.md`](SPECS.md) — ce que l'on construit, les décisions prises et la méthode de travail
- [`AVANCEMENT.md`](AVANCEMENT.md) — où en est le portage, écran par écran
- [`PRIVACY_POLICY.md`](PRIVACY_POLICY.md) — la politique de confidentialité, texte de référence

## Structure

```
project.yml                  description du projet, source de vérité (XcodeGen)
Sources/Shared/              tout le code de l'app (SwiftUI)
  Data/                      base SQLite, modèles, repositories (GRDB)
  Design/                    couleurs et polices du thème Flutter
  Features/                  un dossier par écran
  Preferences/               équivalent de PrefsUtil
Sources/Supporting/          entitlements
Resources/                   polices Poppins, icône d'app, images
Tests/                       tests unitaires
ci_scripts/                  Xcode Cloud
```

## Construire

`project.yml` est la source de vérité. Après toute modification, régénérer :

```sh
xcodegen generate
open NannyPlus.xcodeproj
```

Le `.xcodeproj` est malgré tout committé : Xcode Cloud a besoin de trouver le
projet et son schéma partagé dans le dépôt.

Une seule cible, `NannyPlus-iOS`. La cible macOS, qui servait à lancer l'app
sans simulateur, a été retirée.

Tests :

```sh
xcodebuild -project NannyPlus.xcodeproj -scheme NannyPlus-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Livraison

Dépôt : [ymauray/nannyplus.ios](https://github.com/ymauray/nannyplus.ios).

`main` est **protégée**, sans exception pour l'administrateur : le travail passe
par une branche puis une *pull request*, fusionnée en squash ou en rebase.
La fusion exige le check `Compilation et tests iOS` au vert et une branche à
jour avec `main`.

Deux pipelines, qui ne valident pas la même chose :

- **GitHub Actions** (`.github/workflows/ios.yml`) se déclenche sur toutes les
  branches : régénération par XcodeGen, compilation, tests.
- **Xcode Cloud** (`ci_scripts/ci_post_clone.sh`) surveille `dev` : il ajoute
  la résolution figée des paquets, la signature et la livraison TestFlight.
  **Tout push sur `dev` livre donc une build**, sur la fiche d'app du bundle
  identifier de développement. `main` ne déclenche plus rien.

Le numéro de build vient d'Xcode Cloud, pas de `project.yml` : le script de
post-clone y reporte `$CI_BUILD_NUMBER` avant de régénérer le projet. Le
détail, et les trois pièges rencontrés à la mise en place, sont dans la section
« Livraison » d'[`AVANCEMENT.md`](AVANCEMENT.md).

## Base de données

L'app ouvre `Documents/childcare.db`, exactement le chemin utilisé par sqflite
côté Flutter.

**Elle n'ouvre pourtant pas la base de l'app Flutter**, parce qu'elle porte
désormais un autre bundle identifier — `ch.yannickmauray.nannyplusios` — pour
cohabiter avec la version de production sur TestFlight. Le conteneur diffère,
donc la base aussi : la version native démarre sur une base vide et se remplit
soit par une restauration, soit par le jeu de démonstration.

Le jour du remplacement sur l'App Store, reprendre `ch.frenchguy.nannyplus`
rendra la base existante visible sans import ni conversion, le chemin étant le
même.
