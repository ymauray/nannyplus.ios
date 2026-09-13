# Consignes de travail

Portage 1:1 de l'app Flutter Nanny+ vers iOS natif. Ce fichier ne contient que
ce qui ne se déduit pas du code. Le reste est ailleurs :

- [`SPECS.md`](SPECS.md) — ce que l'on construit et **pourquoi**, les décisions prises, la méthode
- [`AVANCEMENT.md`](AVANCEMENT.md) — **où on en est**, écran par écran, et les pièges déjà rencontrés
- [`README.md`](README.md) — structure du dépôt, compilation, livraison

## La contrainte, avant tout le reste

**Réplique fidèle, défauts d'ergonomie compris.** Un comportement qui paraît
bancal se reproduit tel quel, et se documente dans `AVANCEMENT.md` ; il ne se
corrige que sur décision de Yannick. La référence est la branche `main` du
projet Flutter voisin `../nannyplus`, pas la version du dépôt courant.

## Compiler

`project.yml` est la source de vérité. **Après toute modification, relancer
`xcodegen generate`** — le `.xcodeproj` est committé malgré sa génération, pour
qu'Xcode Cloud trouve le projet et son schéma.

```sh
xcodebuild -project NannyPlus.xcodeproj -scheme NannyPlus-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 16 (référence)' test
```

**Zéro avertissement.** Filtrer la sortie sur `warning:` autant que sur
`error:` : deux avertissements de concurrence ont atteint la CI pour avoir été
cherchés sur le seul `error:`.

## Vérifier un écran

**Aucun écran n'est terminé sans avoir été vu sur simulateur iPhone.** Le
simulateur de travail est « iPhone 16 (référence) », aligné sur l'appareil de
Yannick, avec `xcrun simctl ui <appareil> content_size medium`. Les captures de
référence viennent toujours de son téléphone : les demander et attendre.

Les mesures se font en points, jamais en pixels. Et on lit le style **rendu**,
pas le style écrit : le Dart demande souvent une graisse que Flutter n'applique
pas.

## Git

Six règles, sans exception : jamais de commit ni de push sans y être invité, ne
pas les suggérer non plus, s'identifier comme co-auteur, messages en français au
format *conventional commits*.

`main` est protégée. Le travail passe par une branche puis une *pull request*,
fusionnée en squash ou en rebase, jamais par un commit de fusion. **Une fusion
sur `main` déclenche une livraison TestFlight** : ce n'est pas un geste anodin.

## Données

L'app ouvre la base réelle de Yannick. Aucune donnée réelle n'entre dans
l'historique : ni base SQLite, ni PDF produit par l'app, ni plist de
préférences. Vérifier avant de committer.
