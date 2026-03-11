# Build & Release Guide

Ce guide documente une procédure simple et répétable pour préparer une release MuniConvert.

## 1. Préparation locale

1. Vérifier l'état Git:
   - `git status`
2. Mettre la branche à jour:
   - `git pull --ff-only`
3. Vérifier le build et les tests:
   - `swift build`
   - `swift test`

## 2. Vérifications produit

- Vérifier les profils de conversion critiques
- Vérifier le mode simulation
- Vérifier les garde-fous UX avant conversion réelle
- Vérifier l'export du journal

## 3. Mise à jour documentaire

- Mettre à jour `CHANGELOG.md`
- Mettre à jour `README.md` si fonctionnalités visibles changées

## 4. Tag et release GitHub

1. Commit final:
   - `git add ...`
   - `git commit -m "<message>"`
2. Push `main`:
   - `git push origin main`
3. Créer et pousser un tag annoté:
   - `git tag -a vX.Y.Z -m "MuniConvert vX.Y.Z"`
   - `git push origin vX.Y.Z`
4. Créer la release GitHub:
   - `gh release create vX.Y.Z --title "MuniConvert vX.Y.Z" --notes "..."`

## 5. Distribution macOS (périmètre)

MuniConvert est actuellement distribué comme projet source Swift Package.

Pour une distribution `.app` grand public:

- signature Apple Developer
- notarisation Apple
- vérification Gatekeeper

Ces étapes nécessitent un compte Apple Developer actif et sont hors périmètre automatique de ce guide.
