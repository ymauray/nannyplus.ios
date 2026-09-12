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
xcodegen generate

echo "Projet régénéré depuis project.yml."
