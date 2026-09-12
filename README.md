# Nanny+ — version native iOS/macOS

Portage 1:1 de l'app Flutter `../nannyplus`. Voir `HANDOFF.md` pour le contexte,
les décisions prises et l'état d'avancement.

## Construire

`project.yml` est la source de vérité. Après toute modification, régénérer :

```sh
xcodegen generate
open NannyPlus.xcodeproj
```

Le `.xcodeproj` est malgré tout committé, comme sur Clepsydre : Xcode Cloud a
besoin de trouver le projet et son schéma partagé dans le dépôt.

Tests :

```sh
xcodebuild -project NannyPlus.xcodeproj -scheme NannyPlus-iOS \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Deux cibles partagent `Sources/Shared` :

- `NannyPlus-iOS` — la cible publiée ;
- `NannyPlus-macOS` — confort de développement uniquement (compiler et lancer
  sans simulateur), pas un produit desktop.

## Base de données

L'app ouvre `Documents/childcare.db`, exactement le chemin utilisé par sqflite
côté Flutter. Avec le même bundle identifier (`ch.frenchguy.nannyplus`), elle
reprend donc la base existante sans import ni conversion — y compris, sur macOS,
celle du build Flutter de développement, grâce au partage de conteneur sandbox.
