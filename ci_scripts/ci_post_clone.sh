#!/bin/sh
# Xcode Cloud — exécuté après le clonage, avant la compilation.
#
# Le .xcodeproj est committé pour qu'Xcode Cloud trouve le projet et son schéma
# partagé, mais la source de vérité reste project.yml. On le régénère donc ici :
# sans cette étape, Xcode Cloud compilerait le .xcodeproj tel qu'il a été
# committé, qui peut avoir dérivé du spec si quelqu'un a modifié project.yml
# sans relancer xcodegen.
set -e

brew install xcodegen

cd "$CI_PRIMARY_REPOSITORY_PATH"

# Xcode Cloud tient un compteur de builds, mais ne l'écrit pas dans l'app : sans
# cette étape, chaque exécution reprendrait le numéro figé dans project.yml et
# App Store Connect rejetterait le téléversement comme doublon, un numéro de
# build ne pouvant jamais servir deux fois sur un même train de version.
# L'injection se fait avant xcodegen, le numéro venant d'un build setting
# (CFBundleVersion est généré par GENERATE_INFOPLIST_FILE).
if [ -n "$CI_BUILD_NUMBER" ]; then
  sed -i "" -E "s/^( *CURRENT_PROJECT_VERSION: ).*/\1\"$CI_BUILD_NUMBER\"/" project.yml
  echo "Numéro de build : $CI_BUILD_NUMBER."
fi

xcodegen generate

echo "Projet régénéré depuis project.yml."
