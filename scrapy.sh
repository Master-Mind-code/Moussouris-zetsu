#!/bin/bash

# Couleurs 
VERT="\e[32m"   # Succès (200-299)
JAUNE="\e[33m"  # Redirection (300-399)
ORANGE="\e[38;5;214m"  # Erreur client (400-499)
ROUGE="\e[31m"  # Erreur serveur (500-599)
BLANC="\e[37m"  # Pas de réponse
RESET="\e[0m"   # Réinitialisation des couleurs

# Vérifier si un domaine est fourni
if [ -z "$1" ]; then
    echo -e "${ROUGE}Usage: $0 <domaine>${RESET}"
    exit 1
fi

domaine="$1"
echo "Recherche des sous-domaines pour '$domaine'..."

# Récupérer les sous-domaines
common_names=$(curl -s "https://crt.sh/?q=%25.$domaine&output=json" | jq -r '.[].common_name' | sort -u)

# Vérifier s'il y a des résultats
if [ -z "$common_names" ]; then
    echo -e "${ROUGE} Aucun sous-domaine trouvé.${RESET}"
    exit 1
fi

# Vérifier chaque sous-domaine
while read -r cn; do
    ip=$(dig +short "$cn" | head -n 1)
    [ -z "$ip" ] && ip="Aucune IP"

    http_code=$(curl -o /dev/null -s -w "%{http_code}" --max-time 3 "http://$cn")

    # Déterminer la couleur du [+]
    case $http_code in
        2*) couleur=$VERT ;;  # Succès
        3*) couleur=$JAUNE ;; # Redirection
        4*) couleur=$ORANGE ;; # Erreur client
        5*) couleur=$ROUGE ;; # Erreur serveur
        *) couleur=$BLANC ;;  # Pas de réponse
    esac

    # Affichage final
    echo -e "${couleur}[+]${RESET} $cn $ip $http_code"
done <<< "$common_names"

