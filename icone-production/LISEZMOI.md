# Icône de production

L'icône bleue, celle de l'app Flutter en production, mise de côté le 20 septembre
2026 quand le portage a pris une icône violette pour se distinguer d'elle sur le
téléphone.

Ces fichiers sont ceux du dépôt à ce moment-là, récupérés tels quels. Ce dossier
n'est pas dans les sources du projet : rien d'ici n'entre dans l'app.

**À remettre en place avant la mise en production**, en même temps que le
bundle identifier `ch.frenchguy.nannyplus` :

```sh
cp icone-production/*.png Resources/Assets.xcassets/AppIcon.appiconset/
```

Le point est consigné dans « À revoir une fois le portage initial terminé »
d'[`AVANCEMENT.md`](../AVANCEMENT.md).
