#!/bin/bash

# =============================================================================
# OUTIL AVANCÉ DE RECONNAISSANCE DE SOUS-DOMAINES 
# =============================================================================
# Auteur : MOUSSOURIS CLASSE 1  
# Formation : Ethical Hacking
# Description : Outil avancé d'énumération de sous-domaines avec reporting
# =============================================================================

# Couleurs pour l'affichage
declare -r VERT="\e[32m"        # Succès (200-299)
declare -r JAUNE="\e[33m"       # Redirection (300-399)  
declare -r ORANGE="\e[38;5;214m" # Erreur client (400-499)
declare -r ROUGE="\e[31m"       # Erreur serveur (500-599)
declare -r BLANC="\e[37m"       # Pas de réponse
declare -r BLEU="\e[34m"        # Information
declare -r RESET="\e[0m"        # Reset

# Configuration par défaut
declare -r MAX_THREADS=10
declare -r TIMEOUT=5
declare -r USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"

# Bannière
show_banner() {
    echo -e "${BLEU}"
    echo "############################################################"
    echo "###                                                      ###"
    echo "###     OUTIL AVANCÉ DE RECONNAISSANCE DE SOUS-DOMAINE   ###"
    echo "###             Formation Ethical Hacking                ###"
    echo "###                                                      ###"
    echo "############################################################"
    echo -e "${RESET}"
}

# Vérification des dépendances
check_dependencies() {
    local deps=("curl" "jq" "dig" "parallel")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${ROUGE}[!] Dépendances manquantes : ${missing[*]}${RESET}"
        echo -e "${JAUNE}[i] Installation suggérée :${RESET}"
        echo "    sudo apt-get install curl jq dnsutils parallel"
        exit 1
    fi
}

# Aide (usage)
usage() {
    echo -e "${JAUNE}Utilisation : $0 <domaine> [options]${RESET}"
    echo
    echo "Options :"
    echo "  -o, --output DIR    Répertoire de sortie (par défaut : ./rapports)"
    echo "  -t, --threads N     Nombre de threads (par défaut : $MAX_THREADS)"
    echo "  -h, --help          Afficher cette aide"
    echo
    echo "Exemples :"
    echo "  $0 exemple.com"
    echo "  $0 exemple.com -o /tmp/recon -t 20"
}

# Fonction de scan d'un sous-domaine
scan_subdomain() {
    local subdomain="$1"
    local output_file="$2"
    
    # Résolution IP
    local ip=$(dig +short "$subdomain" A | head -n 1 | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$')
    [ -z "$ip" ] && ip="N/A"
    
    # Test HTTP
    local http_code=$(curl -L -o /dev/null -s -w "%{http_code}" \
        --max-time "$TIMEOUT" \
        --user-agent "$USER_AGENT" \
        --connect-timeout 3 \
        "http://$subdomain" 2>/dev/null)
    
    # Test HTTPS
    local https_code=$(curl -L -o /dev/null -s -w "%{http_code}" \
        --max-time "$TIMEOUT" \
        --user-agent "$USER_AGENT" \
        --connect-timeout 3 \
        "https://$subdomain" 2>/dev/null)
    
    # Détection du serveur (via headers)
    local server=$(curl -I -s --max-time "$TIMEOUT" \
        --user-agent "$USER_AGENT" \
        "http://$subdomain" 2>/dev/null | \
        grep -i "server:" | cut -d' ' -f2- | tr -d '\r\n' | head -c 20)
    [ -z "$server" ] && server="N/A"
    
    # Déterminer le statut et la couleur
    local couleur=$BLANC
    local status="INACTIF"
    
    if [[ "$http_code" =~ ^2 ]] || [[ "$https_code" =~ ^2 ]]; then
        couleur=$VERT
        status="ACTIF"
    elif [[ "$http_code" =~ ^3 ]] || [[ "$https_code" =~ ^3 ]]; then
        couleur=$JAUNE  
        status="REDIRECTION"
    elif [[ "$http_code" =~ ^4 ]] || [[ "$https_code" =~ ^4 ]]; then
        couleur=$ORANGE
        status="ERREUR_CLIENT"
    elif [[ "$http_code" =~ ^5 ]] || [[ "$https_code" =~ ^5 ]]; then
        couleur=$ROUGE
        status="ERREUR_SERVEUR"
    fi
    
    # Affichage temps réel
    printf "${couleur}[+]${RESET} %-30s %-15s %-15s %-3s/%-3s %-20s\n" \
        "$subdomain" "$ip" "$status" "$http_code" "$https_code" "$server"
    
    # Sauvegarde temporaire
    printf "%-30s|%-15s|%-15s|%-3s|%-3s|%-20s\n" \
        "$subdomain" "$ip" "$status" "$http_code" "$https_code" "$server" >> "$output_file.tmp"
}

# Fonction principale
main() {
    local domain=""
    local output_dir="./rapports"
    local threads=$MAX_THREADS
    
    # Lecture des arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output) output_dir="$2"; shift 2 ;;
            -t|--threads) threads="$2"; shift 2 ;;
            -h|--help) usage; exit 0 ;;
            -*) echo -e "${ROUGE}[!] Option inconnue : $1${RESET}"; usage; exit 1 ;;
            *) domain="$1"; shift ;;
        esac
    done
    
    # Vérification domaine
    if [ -z "$domain" ]; then
        echo -e "${ROUGE}[!] Domaine requis${RESET}"
        usage
        exit 1
    fi
    
    show_banner
    check_dependencies
    
    mkdir -p "$output_dir"
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local report_file="$output_dir/${domain}_rapport_${timestamp}.txt"
    local csv_file="$output_dir/${domain}_rapport_${timestamp}.csv"
    local temp_file="$output_dir/${domain}_temp_$$"
    
    echo -e "${BLEU}[i] Démarrage du scan pour : $domain${RESET}"
    echo -e "${BLEU}[i] Threads : $threads | Timeout : ${TIMEOUT}s${RESET}"
    echo -e "${BLEU}[i] Rapport : $report_file${RESET}"
    echo
    
    # Énumération des sous-domaines
    echo -e "${JAUNE}[*] Énumération des sous-domaines via crt.sh...${RESET}"
    local subdomains=$(curl -s "https://crt.sh/?q=%25.$domain&output=json" | \
        jq -r '.[].common_name' 2>/dev/null | \
        grep -v '*' | \
        sort -u | \
        grep -E "^[a-zA-Z0-9.-]+\.$domain$")
    
    if [ -z "$subdomains" ]; then
        echo -e "${ROUGE}[!] Aucun sous-domaine trouvé pour $domain${RESET}"
        exit 1
    fi
    
    local count=$(echo "$subdomains" | wc -l)
    echo -e "${VERT}[+] $count sous-domaines trouvés${RESET}"
    echo
    
    # En-tête tableau
    printf "${BLEU}%-32s %-15s %-15s %-7s %-20s${RESET}\n" \
        "SOUS-DOMAINE" "ADRESSE IP" "STATUT" "HTTP/S" "SERVEUR"
    echo "$(printf '%*s' 90 '' | tr ' ' '-')"
    
    > "$temp_file.tmp"
    
    export -f scan_subdomain
    export TIMEOUT USER_AGENT VERT JAUNE ORANGE ROUGE BLANC BLEU RESET temp_file
    
    echo "$subdomains" | parallel -j "$threads" scan_subdomain {} "$temp_file"
    
    echo
    echo -e "${BLEU}[i] Génération des rapports...${RESET}"
    
    # Rapport texte
    {
        echo "==================================================================="
        echo "RAPPORT DE RECONNAISSANCE - SOUS-DOMAINES"
        echo "==================================================================="
        echo "Domaine cible    : $domain"
        echo "Date/Heure       : $(date)"
        echo "Sous-domaines    : $count trouvés"
        echo "Threads utilisés : $threads"
        echo "==================================================================="
        echo
        printf "%-30s | %-15s | %-15s | HTTP | HTTPS | %-20s\n" \
            "SOUS-DOMAINE" "ADRESSE IP" "STATUT" "SERVEUR"
        echo "$(printf '%*s' 95 '' | tr ' ' '-')"
        
        sort -t'|' -k3,3r "$temp_file.tmp" | while IFS='|' read -r sub ip status http https server; do
            printf "%-30s | %-15s | %-15s | %-4s | %-5s | %-20s\n" \
                "$sub" "$ip" "$status" "$http" "$https" "$server"
        done
        
        echo
        echo "==================================================================="
        echo "STATISTIQUES"
        echo "==================================================================="
        echo "Total sous-domaines : $count"
        echo "Actifs (2xx)        : $(grep -c "|ACTIF|" "$temp_file.tmp" 2>/dev/null )"
        echo "Redirections (3xx)  : $(grep -c "|REDIRECTION|" "$temp_file.tmp" 2>/dev/null )"
        echo "Erreurs client (4xx): $(grep -c "|ERREUR_CLIENT|" "$temp_file.tmp" 2>/dev/null )"
	echo "Erreurs serveur (5xx): $(grep -c "|ERREUR_SERVEUR|" "$temp_file.tmp" 2>/dev/null )"
        echo "Inactifs            : $(grep -c "|INACTIF|" "$temp_file.tmp" 2>/dev/null )"
        
    } > "$report_file"
    
    # Rapport CSV
    {
        echo "sous_domaine,ip,statut,code_http,code_https,serveur"
        sed 's/|/,/g' "$temp_file.tmp"
    } > "$csv_file"
    
    rm -f "$temp_file.tmp"
    
    echo
    echo -e "${VERT}[+] Scan terminé avec succès !${RESET}"
    echo -e "${BLEU}[i] Rapport texte : $report_file${RESET}"
    echo -e "${BLEU}[i] Rapport CSV   : $csv_file${RESET}"
    echo -e "${BLEU}[i] Sous-domaines actifs : $(grep -c "ACTIF" "$report_file" 2>/dev/null || echo 0)/$count${RESET}"
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

