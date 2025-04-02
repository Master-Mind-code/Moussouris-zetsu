#!/bin/bash

# Vérifier si un nom de domaine est donné
if [ "$1" = "" ]; then
    echo "Utilisation : ./script.sh nomdedomaine.com"
    exit 1
fi

# Récupérer le nom de domaine 
DOMAIN=$1
DIR="footprinting-$DOMAIN"
mkdir -p "$DIR"

echo "[+] Collecte des informations sur $DOMAIN..."

# Whois Informations sur le domaine
whois $DOMAIN > "$DIR/whois.txt"
echo "[+] Whois terminé."

# Nslookup - Vérification des serveurs DNS
nslookup $DOMAIN > "$DIR/nslookup.txt"
echo "[+] Nslookup terminé."

# Dig Enregistrements DNS
dig $DOMAIN ANY > "$DIR/dig.txt"
echo "[+] Dig terminé."

# TheHarvester  Recherche d'informations en ligne
theHarvester -d $DOMAIN -l 500 -b all > "$DIR/theHarvester.txt"
echo "[+] TheHarvester terminé."

# Traceroute Chemin parcouru par les données
traceroute $DOMAIN > "$DIR/traceroute.txt"
echo "[+] Traceroute terminé."

# Host  Informations sur le serveur
host -a $DOMAIN > "$DIR/host.txt"
echo "[+] Host terminé."

# Message final
echo "Footprinting terminé."

