#!/bin/bash

# Vérifie si le répertoire est déjà un dépôt Git
if [ -d ".git" ]; then
    echo "Dépôt Git déjà initialisé."
else
    echo "Initialisation du dépôt Git..."
    git init
    git branch -M main
    echo "Entrez l'URL de votre dépôt GitHub :"
    read REPO_URL
    git remote add origin "$REPO_URL"
    echo "Configuration terminée."
fi

# Ajoute les fichiers, commit et push
git add .
echo "Entrez un message de commit :"
read COMMIT_MSG
git commit -m "$COMMIT_MSG"
git push -u origin main

echo "Push terminé avec succès !"

