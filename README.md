# Advanced Subdomain Recon Tool

## Auteur
MOUSSOURIS CLASSE 1  
Formation : Ethical Hacking

---

## Description

Advanced Subdomain Recon Tool v2.0 est un outil avancé d’énumération et d’analyse de sous-domaines pour un domaine cible.

Il permet de :
- Énumérer les sous-domaines via crt.sh
- Résoudre les adresses IP des sous-domaines
- Scanner les services HTTP et HTTPS
- Détecter les codes de statut (2xx, 3xx, 4xx, 5xx)
- Identifier les technologies serveur via les headers HTTP
- Générer des rapports TXT et CSV
- Accélérer les scans grâce à l’exécution parallèle

Le script est écrit en Bash pur et utilise uniquement des outils open-source standards.

---

## Fonctionnalités

- Énumération automatique des sous-domaines (crt.sh)
- Résolution DNS IPv4
- Scan HTTP/HTTPS avec détection des statuts
- Détection du serveur via le header "Server"
- Génération de rapports :
  - TXT : lisible et coloré avec résumé
  - CSV : exploitable pour automatisation
- Scan parallèle avec gestion du nombre de threads
- Affichage coloré en temps réel :

  🟢 Vert   : actif (2xx)  
  🟡 Jaune : redirection (3xx)  
  🟠 Orange: erreur client (4xx)  
  🔴 Rouge : erreur serveur (5xx)  
  ⚪ Blanc : non répondant  

---

## Dépendances

- bash
- curl
- jq
- dig (dnsutils)
- parallel

Le script vérifie automatiquement la présence des dépendances et suggère leur installation si nécessaire.

---

## Installation

git clone https://github.com/Master-Mind-code/Moussouris-zetsu.git
cd Moussouris-zetsu
chmod +x scrape.sh

---

## Utilisation

./scrape.sh example.com

ou

bash scrape.sh example.com

---

## Avertissement légal

Cet outil est destiné uniquement à des fins éducatives et de tests autorisés.
Toute utilisation sur des systèmes sans autorisation explicite est interdite.
 
