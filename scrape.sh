#!/bin/bash

# =============================================================================
# OUTIL AVANCÉ DE RECONNAISSANCE DE SOUS-DOMAINES 
# =============================================================================
# Auteur   : MOUSSOURIS CLASSE 1
# Formation: Ethical Hacking
# Description :  Outil avancé d'énumération de sous-domaines avec reporting
# =============================================================================

# === COULEURS ===
declare -r VERT="\e[32m"
declare -r JAUNE="\e[33m"
declare -r ORANGE="\e[38;5;214m"
declare -r ROUGE="\e[31m"
declare -r GRIS="\e[37m"
declare -r BLEU="\e[34m"
declare -r RESET="\e[0m"

# === CONFIGURATION ===
declare -r MAX_THREADS=10
declare -r TIMEOUT=5
declare -r USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"

# === BANNIÈRE ===
show_banner() {
    echo -e "${BLEU}"
    echo "╔════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║        OUTIL AVANCÉ DE RECONNAISSANCE DE SOUS-DOMAINES                             ║"
    echo "║                       Formation: Ethical Hacking                                   ║"
    echo "╚════════════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# === VÉRIFICATION DES DÉPENDANCES ===
check_dependencies() {
    local deps=("curl" "jq" "dig" "parallel")
    local manquants=()
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then manquants+=("$dep"); fi
    done
    if [ ${#manquants[@]} -ne 0 ]; then
        echo -e "${ROUGE}[!] Dépendances manquantes : ${manquants[*]}${RESET}"
        echo -e "${JAUNE}[i] Installe-les via :${RESET}"
        echo "    sudo apt-get install curl jq dnsutils parallel"
        exit 1
    fi
}

# === AIDE ===
usage() {
    echo -e "${JAUNE}Utilisation: $0 <domaine> [options]${RESET}"
    echo "  -o, --output DIR    Répertoire de sortie (par défaut: ./reports)"
    echo "  -t, --threads N     Nombre de threads (défaut: $MAX_THREADS)"
    echo "  -h, --help          Afficher cette aide"
}

# === ANALYSE D’UN SOUS-DOMAINE ===
scan_subdomain() {
    local sous_domaine="$1"
    local fichier_sortie="$2"

    # Résolution DNS
    local ip=$(dig +short "$sous_domaine" A | head -n1)
    [ -z "$ip" ] && ip="N/A"

    # Vérification HTTP et HTTPS
    local code_http=$(curl -L -o /dev/null -s -w "%{http_code}" \
        --max-time "$TIMEOUT" --user-agent "$USER_AGENT" \
        --connect-timeout 3 "http://$sous_domaine" 2>/dev/null)

    local code_https=$(curl -L -o /dev/null -s -w "%{http_code}" \
        --max-time "$TIMEOUT" --user-agent "$USER_AGENT" \
        --connect-timeout 3 "https://$sous_domaine" 2>/dev/null)

    # Détection du serveur
    local serveur=$(curl -I -s --max-time "$TIMEOUT" \
        --user-agent "$USER_AGENT" "http://$sous_domaine" 2>/dev/null | \
        grep -i "server:" | cut -d' ' -f2- | tr -d '\r\n' | head -c 20)
    [ -z "$serveur" ] && serveur="N/A"

    # Détermination du statut
    local signe="[+]"
    local couleur=$GRIS
    local statut="INACTIF"

    if [[ "$code_http" =~ ^2 ]] || [[ "$code_https" =~ ^2 ]]; then
        couleur=$VERT; statut="ACTIF"
    elif [[ "$code_http" =~ ^3 ]] || [[ "$code_https" =~ ^3 ]]; then
        couleur=$JAUNE; statut="REDIRECTION"
    elif [[ "$code_http" =~ ^4 ]] || [[ "$code_https" =~ ^4 ]]; then
        couleur=$ORANGE; statut="ERREUR_CLIENT"
    elif [[ "$code_http" =~ ^5 ]] || [[ "$code_https" =~ ^5 ]]; then
        couleur=$ROUGE; statut="ERREUR_SERVEUR"
    fi

    # Affichage
    printf "${couleur}${signe}${RESET} %-50s %-15s %-15s %-6s %-6s %-20s\n" \
        "$sous_domaine" "$ip" "$statut" "$code_http" "$code_https" "$serveur"

    # Sauvegarde temporaire
    printf "%-50s|%-15s|%-15s|%-3s|%-3s|%-20s\n" \
        "$sous_domaine" "$ip" "$statut" "$code_http" "$code_https" "$serveur" >> "$fichier_sortie.tmp"
}

# === FONCTION PRINCIPALE ===
main() {
    local domaine=""
    local dossier_sortie="./reports"
    local threads=$MAX_THREADS

    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output) dossier_sortie="$2"; shift 2;;
            -t|--threads) threads="$2"; shift 2;;
            -h|--help) usage; exit 0;;
            *) domaine="$1"; shift;;
        esac
    done

    [ -z "$domaine" ] && { echo -e "${ROUGE}[!] Domaine requis${RESET}"; usage; exit 1; }

    show_banner
    check_dependencies
    mkdir -p "$dossier_sortie"

    local horodatage=$(date +"%Y%m%d_%H%M%S")
    local rapport_txt="$dossier_sortie/${domaine}_rapport_${horodatage}.txt"
    local rapport_csv="$dossier_sortie/${domaine}_rapport_${horodatage}.csv"
    local fichier_temp="$dossier_sortie/${domaine}_temp_$$"

    echo -e "${BLEU}[i] Lancement du scan : $domaine | Threads : $threads | Timeout : ${TIMEOUT}s${RESET}\n"

    # Récupération des sous-domaines depuis crt.sh
    local sous_domaines=$(curl -s "https://crt.sh/?q=%25.$domaine&output=json" | \
        jq -r '.[].common_name' 2>/dev/null | grep -v '*' | sort -u | grep -E "^[a-zA-Z0-9.-]+\.$domaine$")

    if [ -z "$sous_domaines" ]; then
        echo -e "${ROUGE}[!] Aucun sous-domaine trouvé${RESET}"; exit 1
    fi

    local total=$(echo "$sous_domaines" | wc -l)
    echo -e "${VERT}[+] $total sous-domaines uniques trouvés${RESET}\n"

    # Tableau en-tête
    echo "╔══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╗"
    echo "║ [+] SOUS-DOMAINE                                       ║ IP             ║ STATUT         ║ HTTP ║ HTTPS ║ SERVEUR                   ║"
    echo "╠══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╣"

    > "$fichier_temp.tmp"
    export -f scan_subdomain; export TIMEOUT USER_AGENT VERT JAUNE ORANGE ROUGE GRIS BLEU RESET fichier_temp
    echo "$sous_domaines" | parallel -j "$threads" scan_subdomain {} "$fichier_temp"

    echo "╚══════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════════╝"

    echo -e "\n${BLEU}[i] Génération des rapports...${RESET}"

    # CSV
    {
        echo "sous_domaine,ip,statut,code_http,code_https,serveur"
        sed 's/|/,/g' "$fichier_temp.tmp"
    } > "$rapport_csv"

    # Rapport texte
    {
        echo "RAPPORT DE RECONNAISSANCE - SOUS-DOMAINES"
        echo "Domaine cible : $domaine"
        echo "Date/Heure    : $(date)"
        echo "Sous-domaines : $total"
        echo
        sort -t'|' -k3,3r "$fichier_temp.tmp" | while IFS='|' read -r sub ip statut http https serveur; do
            printf "%-50s | %-15s | %-15s | %-4s | %-5s | %-20s\n" \
            "$sub" "$ip" "$statut" "$http" "$https" "$serveur"
        done
        echo
        echo "STATISTIQUES"
        echo "Total            : $total"
        echo "Actifs (2xx)     : $(grep -c 'ACTIF' "$fichier_temp.tmp")"
        echo "Redirections     : $(grep -c 'REDIRECTION' "$fichier_temp.tmp")"
        echo "Erreurs client   : $(grep -c 'ERREUR_CLIENT' "$fichier_temp.tmp")"
        echo "Erreurs serveur  : $(grep -c 'ERREUR_SERVEUR' "$fichier_temp.tmp")"
        echo "Inactifs         : $(grep -c 'INACTIF' "$fichier_temp.tmp")"
    } > "$rapport_txt"

    rm -f "$fichier_temp.tmp"

    echo -e "${VERT}[+] Scan terminé avec succès !${RESET}"
    echo -e "${BLEU}[i] Rapport texte : $rapport_txt${RESET}"
    echo -e "${BLEU}[i] Rapport CSV   : $rapport_csv${RESET}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

