#!/bin/bash

# ==============================
# 🎨 Couleurs
# ==============================
declare -r VERT="\e[32m"
declare -r JAUNE="\e[33m"
declare -r ORANGE="\e[38;5;214m"
declare -r ROUGE="\e[31m"
declare -r BLANC="\e[37m"
declare -r BLEU="\e[34m"
declare -r RESET="\e[0m"

# ==============================
# ⚙️ Configuration par défaut
# ==============================
declare -r MAX_THREADS=10
declare -r TIMEOUT=5
declare -r USER_AGENT="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"

# ==============================
# 🎭 Bannière
# ==============================
show_banner() {
    echo -e "${BLEU}"
    echo "╔════════════════════════════════════════════════════════════════════════════╗"
    echo "║                OUTIL AVANCÉ DE RECONNAISSANCE DE SOUS-DOMAINES             ║"
    echo "║                   Formation Ethical Hacking                                ║"
    echo "╚════════════════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
}

# ==============================
# 🔍 Vérification des dépendances
# ==============================
check_dependencies() {
    local deps=("curl" "jq" "dig" "parallel")
    local missing=()
    for dep in "${deps[@]}"; do
        command -v "$dep" >/dev/null 2>&1 || missing+=("$dep")
    done

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${ROUGE}[!] Dépendances manquantes : ${missing[*]}${RESET}"
        echo -e "${JAUNE}[i] Installation suggérée :${RESET}"
        echo "    sudo apt-get install curl jq dnsutils parallel"
        exit 1
    fi
}

# ==============================
# 📖 Aide / Usage
# ==============================
usage() {
    echo -e "${JAUNE}Usage: $0 <domaine> [options]${RESET}"
    echo
    echo "Options disponibles :"
    echo "  -o, --output DIR    Répertoire de sortie (défaut: ./reports)"
    echo "  -t, --threads N     Nombre de threads (défaut: $MAX_THREADS)"
    echo "  -h, --help          Afficher cette aide"
}

# ==============================
# 🔬 Scan d’un sous-domaine
# ==============================
scan_subdomain() {
    local subdomain="$1"
    local output_file="$2"

    # Récupérer l’IP
    local ip=$(dig +short "$subdomain" A | head -n1)
    [ -z "$ip" ] && ip="N/A"

    # Vérifier HTTP et HTTPS
    local http_code=$(curl -L -o /dev/null -s -w "%{http_code}" \
        --max-time "$TIMEOUT" --user-agent "$USER_AGENT" \
        "http://$subdomain" 2>/dev/null)
    
    local https_code=$(curl -L -o /dev/null -s -w "%{http_code}" \
        --max-time "$TIMEOUT" --user-agent "$USER_AGENT" \
        "https://$subdomain" 2>/dev/null)

    # Détecter serveur
    local server=$(curl -I -s --max-time "$TIMEOUT" --user-agent "$USER_AGENT" \
        "http://$subdomain" 2>/dev/null | grep -i "server:" | cut -d' ' -f2- | tr -d '\r\n')
    [ -z "$server" ] && server="N/A"

    # Déterminer couleur et statut
    local couleur=$BLANC
    local status="DEAD"
    local icon="[+]"

    if [[ "$http_code" =~ ^2 ]] || [[ "$https_code" =~ ^2 ]]; then
        couleur=$VERT; status="ALIVE"
    elif [[ "$http_code" =~ ^3 ]] || [[ "$https_code" =~ ^3 ]]; then
        couleur=$JAUNE; status="REDIRECT"
    elif [[ "$http_code" =~ ^4 ]]; then
        couleur=$ORANGE; status="CLIENT_ERR"
    elif [[ "$http_code" =~ ^5 ]]; then
        couleur=$ROUGE; status="SERVER_ERR"
    fi

    # Affichage
    printf "║ ${couleur}%s${RESET} %-40s ║ %-12s ║ %-11s ║ %-6s ║ %-6s ║ %-12s ║\n" \
        "$icon" "$subdomain" "$ip" "$status" "$http_code" "$https_code" "$server"

    # Sauvegarde temporaire
    printf "%-40s|%-12s|%-11s|%-6s|%-6s|%-12s\n" \
        "$subdomain" "$ip" "$status" "$http_code" "$https_code" "$server" >> "$output_file.tmp"
}

# ==============================
# 🚀 Programme principal
# ==============================
main() {
    local domain=""
    local output_dir="./reports"
    local threads=$MAX_THREADS

    # Parsing des arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--output) output_dir="$2"; shift 2;;
            -t|--threads) threads="$2"; shift 2;;
            -h|--help) usage; exit 0;;
            *) domain="$1"; shift;;
        esac
    done

    [ -z "$domain" ] && { echo -e "${ROUGE}[!] Domaine requis${RESET}"; usage; exit 1; }

    show_banner
    check_dependencies
    mkdir -p "$output_dir"

    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local csv_file="$output_dir/${domain}_recon_${timestamp}.csv"
    local temp_file="$output_dir/${domain}_temp_$$"

    echo -e "${BLEU}[i] Démarrage du scan pour : $domain${RESET}"
    echo -e "${BLEU}[i] Threads : $threads | Timeout : ${TIMEOUT}s${RESET}\n"

    # Récupération des sous-domaines via crt.sh
    local subdomains=$(curl -s "https://crt.sh/?q=%25.$domain&output=json" | \
        jq -r '.[].common_name' 2>/dev/null | grep -v '*' | sort -u | grep -E "^[a-zA-Z0-9.-]+\.$domain$")
    
    [ -z "$subdomains" ] && { echo -e "${ROUGE}[!] Aucun sous-domaine trouvé${RESET}"; exit 1; }
    local count=$(echo "$subdomains" | wc -l)
    echo -e "${VERT}[+] $count sous-domaines trouvés${RESET}\n"

    # En-tête tableau
    echo "╔════════════════════════════════════════════════════════════════════════════╗"
    echo "║ SOUS-DOMAINE                            ║ IP           ║ STATUT      ║ HTTP ║ HTTPS║ SERVEUR      ║"
    echo "╠════════════════════════════════════════════════════════════════════════════╣"

    > "$temp_file.tmp"
    export -f scan_subdomain
    export TIMEOUT USER_AGENT VERT JAUNE ORANGE ROUGE BLANC BLEU RESET temp_file

    # Scan parallèle
    echo "$subdomains" | parallel -j "$threads" scan_subdomain {} "$temp_file"

    echo "╚════════════════════════════════════════════════════════════════════════════╝"

    # Génération CSV
    {
        echo "subdomain,ip,status,http_code,https_code,server"
        sed 's/|/,/g' "$temp_file.tmp"
    } > "$csv_file"

    # Statistiques
    local alive=$(grep -c "ALIVE" "$temp_file.tmp")
    local redirect=$(grep -c "REDIRECT" "$temp_file.tmp")
    local client_err=$(grep -c "CLIENT_ERR" "$temp_file.tmp")
    local server_err=$(grep -c "SERVER_ERR" "$temp_file.tmp")
    local dead=$(grep -c "DEAD" "$temp_file.tmp")

    echo -e "\n${BLEU}=================== STATISTIQUES ===================${RESET}"
    echo "Total sous-domaines : $count"
    echo "Actifs (2xx)        : $alive"
    echo "Redirections (3xx)  : $redirect"
    echo "Erreurs client (4xx): $client_err"
    echo "Erreurs serveur (5xx): $server_err"
    echo "Non répondants      : $dead"

    rm -f "$temp_file.tmp"

    echo -e "\n${VERT}[+] Scan terminé !${RESET}"
    echo -e "${BLEU}[i] Rapport CSV généré : $csv_file${RESET}"
}

# ==============================
# 🎯 Point d’entrée
# ==============================
[[ "${BASH_SOURCE[0]}" == "${0}" ]] && main "$@"

