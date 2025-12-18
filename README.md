# Advanced Subdomain Recon Tool 

## Auteur
**MOUSSOURIS CLASSE 1**  
Formation : **Ethical Hacking**  

---

## Description
Advanced Subdomain Recon Tool v2.0 est un **outil avancé d’énumération de sous-domaines** pour un domaine cible.  
Il effectue :  

- Énumération via **crt.sh**  
- Résolution IP des sous-domaines  
- Scan HTTP/HTTPS avec détection des codes de statut  
- Détection de technologie serveur via headers HTTP  
- Génération de rapports **TXT et CSV**  
- Scan **parallèle** pour accélérer le processus  

Le script est entièrement écrit en **Bash pur**, utilisant uniquement des outils open-source (`curl`, `jq`, `dig`, `parallel`).

---

## Fonctionnalités principales

1. **Enumération de sous-domaines** : via crt.sh, filtrage et tri automatique.  
2. **Résolution IP** : récupération IPv4 valide pour chaque sous-domaine.  
3. **Scan HTTP/HTTPS** : détection des codes `2xx`, `3xx`, `4xx`, `5xx`.  
4. **Détection serveur** : identification via header `Server`.  
5. **Rapports détaillés** :  
   - TXT : lisible et coloré avec résumé statistique  
   - CSV : pour traitement automatisé  
6. **Affichage coloré en temps réel**  
   - 🟢  Vert : actif (2xx)  
   - 🟡  Jaune : redirection (3xx)  
   - 🟠  Orange : erreur client (4xx)  
   - 🔴  Rouge : erreur serveur (5xx)  
   - ⚪  Blanc : non répondant  
7. **Parallélisation** : via `parallel`, threads configurables.

---

## Dépendances

- `bash`  
- `curl`  
- `jq`  
- `dig` (dnsutils)  
- `parallel`  

Le script vérifie automatiquement les dépendances et suggère leur installation si elles sont manquantes.


## Installation


```git clone https://github.com/Master-Mind-code/Moussouris-zetsu.git```
```cd Moussouris-zetsu```
```chmod +x scrape.sh```

## Execution du script 
Pour exécutter le script, entrez la commande suivante:
```./scrape.sh example.com```
  ou
```bash scrape.sh example.com```

 
