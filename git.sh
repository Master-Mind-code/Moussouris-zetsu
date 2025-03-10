#!/bin/bash

echo "######################"
echo "### ./GitScript    ###"
echo "### Correction Git ###"
echo "### Do By Zetsu    ###"
echo "######################"

repo_url= https://github.com/Master-Mind-code/Moussouris-zetsu

####main

echo -n "veillez saisir votre message de commit> "
read commit_mes

if [-d .git ]; then 
	echo "Repo initialisé"
	echo "push en cours"

	git add .
	git commit -m "$commit_mes"
	git push
else
     echo " initialisation du repo"


      git init
      git add .  
      git commit -m "$commit_mes"
     git branch -M main
    git remote add $repo_url
    git push -u origin main

fi
                       
