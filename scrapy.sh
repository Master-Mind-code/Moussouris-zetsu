#!/bin/bash

# =============================================================================
# MSRSCRAP EXPERT - Outil Avancé de Reconnaissance de Sous-Domaines
# =============================================================================
# Auteur : MOUSSOURIS CLASSE 1
# Version : 2.0-EXPERT
# Description : Outil professionnel d'énumération avec détection avancée
# =============================================================================

set -euo pipefail

# =============================================================================
# CONFIGURATION GLOBALE
# =============================================================================

declare -r VERSION="2.0-EXPERT"
declare -r SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Couleurs
declare -r VERT="\e[32m"
declare -r JAUNE="\e[33m"
declare -r ORANGE="\e[38;5;214m"
declare -r ROUGE="\e[31m"
declare -r BLANC="\e[37m"
declare -r BLEU="\e[34m"
declare -r CYAN="\e[36m"
declare -r MAGENTA="\e[35m"
declare -r RESET="\e[0m"
declare -r BOLD="\e[1m"

# Configuration par défaut
declare -r MAX_THREADS=20
declare -r TIMEOUT=5
declare -r RATE_LIMIT_DELAY=0.3

# Répertoires
OUTPUT_DIR="./output"
CACHE_DIR="$OUTPUT_DIR/cache"
REPORTS_DIR="$OUTPUT_DIR/reports"
LOGS_DIR="$OUTPUT_DIR/logs"

# User-Agents rotatifs
declare -a USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120.0.0.0"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/120.0.0.0"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
)

# Variables globales
DOMAIN=""
THREADS=$MAX_THREADS
STEALTH_MODE=false
USE_CACHE=true
VERBOSE=false
DEEP_SCAN=false
EXPORT_JSON=false
EXPORT_HTML=false
EXPORT_CSV=false

# Statistiques
declare -A STATS=(
    [total]=0
    [active]=0
    [inactive]=0
    [redirects]=0
    [errors_client]=0
    [errors_server]=0
    [with_waf]=0
)

# =============================================================================
# FONCTIONS UTILITAIRES
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    case "$level" in
        INFO)  echo -e "${BLEU}[INFO]${RESET} $message" ;;
        SUCCESS) echo -e "${VERT}[+]${RESET} $message" ;;
        WARNING) echo -e "${JAUNE}[!]${RESET} $message" ;;
        ERROR) echo -e "${ROUGE}[✗]${RESET} $message" ;;
        DEBUG) [ "$VERBOSE" = true ] && echo -e "${CYAN}[DEBUG]${RESET} $message" ;;
    esac
    
    [ -d "$LOGS_DIR" ] && echo "[$timestamp] [$level] $message" >> "$LOGS_DIR/${DOMAIN}_scan.log"
}

get_random_ua() {
    echo "${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}"
}

rate_limit() {
    [ "$STEALTH_MODE" = true ] && sleep "$RATE_LIMIT_DELAY"
}

# =============================================================================
# BANNIÈRE
# =============================================================================

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << EOF
╔═══════════════════════════════════════════════════════════════════════╗
║                                                                       ║
║   ███╗   ███╗███████╗██████╗ ███████╗ ██████╗██████╗  █████╗ ██████╗  ║
║   ████╗ ████║██╔════╝██╔══██╗██╔════╝██╔════╝██╔══██╗██╔══██╗██╔══██╗ ║
║   ██╔████╔██║███████╗██████╔╝███████╗██║     ██████╔╝███████║██████╔╝ ║
║   ██║╚██╔╝██║╚════██║██╔══██╗╚════██║██║     ██╔══██╗██╔══██║██╔═══╝  ║
║   ██║ ╚═╝ ██║███████║██║  ██║███████║╚██████╗██║  ██║██║  ██║██║      ║
║   ╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝      ║
║                                                                       ║
║                         MOUSSOURIS CLASSE 1                           ║
║                  Advanced Subdomain Enumeration                       ║
║                                                                       ║
╚═══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${RESET}"
}

# =============================================================================
# AIDE
# =============================================================================

usage() {
    cat << EOF
${BOLD}UTILISATION :${RESET}
    $0 -d <domaine> [OPTIONS]

${BOLD}OPTIONS OBLIGATOIRES :${RESET}
    -d, --domain DOMAIN          Domaine cible à analyser

${BOLD}OPTIONS DE SCAN :${RESET}
    -t, --threads N              Nombre de threads (défaut: $MAX_THREADS)
    -D, --deep                   Mode scan approfondi
    -s, --stealth                Mode furtif avec délais
    --no-cache                   Désactiver le cache
    
${BOLD}OPTIONS D'EXPORT :${RESET}
    -o, --output DIR             Répertoire de sortie (défaut: $OUTPUT_DIR)
    --json                       Export JSON
    --html                       Rapport HTML interactif
    --csv                        Export CSV
    --all-formats                Tous les formats

${BOLD}OPTIONS GÉNÉRALES :${RESET}
    -v, --verbose                Mode verbeux
    -h, --help                   Afficher cette aide
    --version                    Afficher la version

${BOLD}EXEMPLES :${RESET}
    # Scan basique
    $0 -d example.com
    
    # Scan expert complet
    $0 -d example.com --deep --stealth --all-formats
    
    # Scan rapide
    $0 -d example.com -t 50 --no-cache

EOF
}

# =============================================================================
# VÉRIFICATION DES DÉPENDANCES
# =============================================================================

check_dependencies() {
    log INFO "Vérification des dépendances..."
    
    local required_deps=("curl")
    local optional_deps=("jq" "dig" "parallel")
    local missing_required=()
    local missing_optional=()
    
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_required+=("$dep")
        fi
    done
    
    if [ ${#missing_required[@]} -ne 0 ]; then
        log ERROR "Dépendances requises manquantes : ${missing_required[*]}"
        echo
        echo -e "${JAUNE}Installation suggérée :${RESET}"
        echo "  sudo apt-get install curl"
        exit 1
    fi
    
    for dep in "${optional_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_optional+=("$dep")
        fi
    done
    
    if [ ${#missing_optional[@]} -ne 0 ]; then
        log WARNING "Dépendances optionnelles manquantes : ${missing_optional[*]}"
        log WARNING "Mode simplifié activé"
    fi
    
    log SUCCESS "Vérification terminée"
}

# =============================================================================
# VALIDATION
# =============================================================================

validate_domain() {
    local domain="$1"
    
    if ! [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log ERROR "Format de domaine invalide : $domain"
        exit 1
    fi
    
    log SUCCESS "Domaine validé : $domain"
}

init_directories() {
    log INFO "Initialisation des répertoires..."
    mkdir -p "$OUTPUT_DIR" "$CACHE_DIR" "$REPORTS_DIR" "$LOGS_DIR"
    mkdir -p "$REPORTS_DIR/$DOMAIN" "$CACHE_DIR/$DOMAIN"
    log SUCCESS "Répertoires créés"
}

# =============================================================================
# SYSTÈME DE CACHE
# =============================================================================

get_cache_file() {
    local key="$1"
    local hash=$(echo -n "$key" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$key")
    echo "$CACHE_DIR/$DOMAIN/$hash.cache"
}

use_cache() {
    local key="$1"
    local cache_file=$(get_cache_file "$key")
    
    if [ "$USE_CACHE" = false ]; then
        return 1
    fi
    
    if [ -f "$cache_file" ]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || stat -f %m "$cache_file" 2>/dev/null)))
        
        if [ $cache_age -lt 86400 ]; then
            log DEBUG "Utilisation du cache pour : $key"
            cat "$cache_file"
            return 0
        fi
    fi
    
    return 1
}

save_cache() {
    local key="$1"
    local data="$2"
    local cache_file=$(get_cache_file "$key")
    
    echo "$data" > "$cache_file"
    log DEBUG "Cache sauvegardé pour : $key"
}

# =============================================================================
# DÉTECTION WILDCARD DNS
# =============================================================================

check_wildcard() {
    if ! command -v dig >/dev/null 2>&1; then
        log WARNING "dig non disponible, vérification wildcard ignorée"
        return 1
    fi
    
    log INFO "Vérification des wildcards DNS..."
    
    local random_sub="random-nonexistent-$(date +%s%N)"
    local wildcard_ip=$(dig +short "${random_sub}.${DOMAIN}" A 2>/dev/null | head -n 1)
    
    if [ -n "$wildcard_ip" ] && [[ "$wildcard_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log WARNING "WILDCARD DNS DÉTECTÉ ! (Résout vers : $wildcard_ip)"
        log WARNING "Les résultats peuvent contenir des faux positifs"
        return 0
    fi
    
    log SUCCESS "Pas de wildcard DNS détecté"
    return 1
}

# =============================================================================
# ÉNUMÉRATION
# =============================================================================

enumerate_crtsh() {
    log INFO "Énumération via crt.sh..."
    
    if use_cache "crtsh_$DOMAIN"; then
        return 0
    fi
    
    local results=$(curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" 2>/dev/null)
    
    if [ -z "$results" ]; then
        log WARNING "crt.sh : Aucun résultat"
        return 1
    fi
    
    local subdomains=""
    if command -v jq >/dev/null 2>&1; then
        subdomains=$(echo "$results" | jq -r '.[].common_name, .[].name_value' 2>/dev/null | \
            sed 's/\*\.//g' | sort -u | grep -E "^[a-zA-Z0-9.-]+\.$DOMAIN$" || true)
    else
        subdomains=$(echo "$results" | \
            grep -o '"common_name":"[^"]*"' | cut -d'"' -f4 | \
            sed 's/\*\.//g' | sort -u | grep -E "^[a-zA-Z0-9.-]+\.$DOMAIN$" || true)
    fi
    
    local count=$(echo "$subdomains" | grep -c . || echo 0)
    
    if [ $count -gt 0 ]; then
        log SUCCESS "crt.sh : $count sous-domaines trouvés"
        save_cache "crtsh_$DOMAIN" "$subdomains"
        echo "$subdomains"
    else
        log WARNING "crt.sh : Aucun sous-domaine trouvé"
    fi
}

enumerate_certspotter() {
    log INFO "Énumération via CertSpotter..."
    
    if use_cache "certspotter_$DOMAIN"; then
        return 0
    fi
    
    rate_limit
    
    local results=$(curl -s "https://api.certspotter.com/v1/issuances?domain=$DOMAIN&include_subdomains=true&expand=dns_names" 2>/dev/null)
    
    if [ -z "$results" ]; then
        return 1
    fi
    
    local subdomains=""
    if command -v jq >/dev/null 2>&1; then
        subdomains=$(echo "$results" | jq -r '.[].dns_names[]' 2>/dev/null | \
            sort -u | grep -E "^[a-zA-Z0-9.-]+\.$DOMAIN$" || true)
    fi
    
    local count=$(echo "$subdomains" | grep -c . || echo 0)
    
    if [ $count -gt 0 ]; then
        log SUCCESS "CertSpotter : $count sous-domaines trouvés"
        save_cache "certspotter_$DOMAIN" "$subdomains"
        echo "$subdomains"
    fi
}

enumerate_all_sources() {
    log INFO "Démarrage de l'énumération multi-sources..."
    echo
    
    local temp_file=$(mktemp)
    
    {
        enumerate_crtsh
        enumerate_certspotter
    } | sort -u > "$temp_file"
    
    local total=$(wc -l < "$temp_file" | tr -d ' ')
    
    if [ "$total" -eq 0 ]; then
        log ERROR "Aucun sous-domaine découvert !"
        rm -f "$temp_file"
        exit 1
    fi
    
    echo
    log SUCCESS "Total unique : $total sous-domaines découverts"
    
    cat "$temp_file"
    rm -f "$temp_file"
}

# =============================================================================
# ANALYSE DES SOUS-DOMAINES
# =============================================================================

resolve_ip() {
    local subdomain="$1"
    
    if ! command -v dig >/dev/null 2>&1; then
        echo "N/A"
        return
    fi
    
    local ipv4=$(dig +short "$subdomain" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)
    
    if [ -n "$ipv4" ]; then
        echo "$ipv4"
    else
        echo "N/A"
    fi
}

test_http() {
    local url="$1"
    local ua=$(get_random_ua)
    
    local http_code=$(curl -L -o /dev/null -s -w "%{http_code}" \
        --max-time "$TIMEOUT" \
        --user-agent "$ua" \
        --connect-timeout 3 \
        -k \
        "$url" 2>/dev/null || echo "000")
    
    echo "$http_code"
}

detect_server() {
    local subdomain="$1"
    local ua=$(get_random_ua)
    
    local server=$(curl -I -s --max-time "$TIMEOUT" \
        --user-agent "$ua" \
        -k \
        "http://$subdomain" 2>/dev/null | \
        grep -i "^server:" | cut -d' ' -f2- | tr -d '\r\n' | head -c 30)
    
    [ -z "$server" ] && server="N/A"
    echo "$server"
}

detect_waf() {
    local subdomain="$1"
    local ua=$(get_random_ua)
    local waf="N/A"
    
    if [ "$DEEP_SCAN" = false ]; then
        echo "$waf"
        return
    fi
    
    local headers=$(curl -I -s --max-time "$TIMEOUT" -A "$ua" -k "https://$subdomain" 2>/dev/null)
    
    if echo "$headers" | grep -qi "cloudflare\|cf-ray"; then
        waf="Cloudflare"
    elif echo "$headers" | grep -qi "x-sucuri"; then
        waf="Sucuri"
    elif echo "$headers" | grep -qi "imperva\|incapsula"; then
        waf="Imperva"
    elif echo "$headers" | grep -qi "akamai"; then
        waf="Akamai"
    fi
    
    [ "$waf" != "N/A" ] && ((STATS[with_waf]++))
    
    echo "$waf"
}

scan_subdomain() {
    local subdomain="$1"
    local output_file="$2"
    
    rate_limit
    
    # Résolution IP
    local ip=$(resolve_ip "$subdomain")
    
    # Tests HTTP/HTTPS
    local http_code=$(test_http "http://$subdomain")
    local https_code=$(test_http "https://$subdomain")
    
    # Déterminer le statut
    local status="INACTIVE"
    local couleur=$BLANC
    
    if [[ "$http_code" =~ ^2 ]] || [[ "$https_code" =~ ^2 ]]; then
        status="ACTIVE"
        couleur=$VERT
        ((STATS[active]++))
    elif [[ "$http_code" =~ ^3 ]] || [[ "$https_code" =~ ^3 ]]; then
        status="REDIRECT"
        couleur=$JAUNE
        ((STATS[redirects]++))
    elif [[ "$http_code" =~ ^4 ]] || [[ "$https_code" =~ ^4 ]]; then
        status="ERROR_4XX"
        couleur=$ORANGE
        ((STATS[errors_client]++))
    elif [[ "$http_code" =~ ^5 ]] || [[ "$https_code" =~ ^5 ]]; then
        status="ERROR_5XX"
        couleur=$ROUGE
        ((STATS[errors_server]++))
    else
        ((STATS[inactive]++))
    fi
    
    # Informations supplémentaires
    local server="N/A"
    local waf="N/A"
    
    if [ "$status" = "ACTIVE" ] || [ "$DEEP_SCAN" = true ]; then
        server=$(detect_server "$subdomain")
        waf=$(detect_waf "$subdomain")
    fi
    
    # Affichage temps réel
    printf "${couleur}[+]${RESET} %-35s ${CYAN}%-15s${RESET} %-12s ${JAUNE}%-4s${RESET}/${VERT}%-4s${RESET} %-20s\n" \
        "$subdomain" "$ip" "$status" "$http_code" "$https_code" "${server:0:20}"
    
    # Sauvegarde
    printf "%s|%s|%s|%s|%s|%s|%s\n" \
        "$subdomain" "$ip" "$status" "$http_code" "$https_code" "$server" "$waf" \
        >> "$output_file"
}

# =============================================================================
# GÉNÉRATION DES RAPPORTS
# =============================================================================

generate_text_report() {
    local input_file="$1"
    local output_file="$2"
    
    log INFO "Génération du rapport texte..."
    
    {
        echo "═══════════════════════════════════════════════════════════════════"
        echo "         MSRSCRAP - RAPPORT D'ÉNUMÉRATION DE SOUS-DOMAINES        "
        echo "═══════════════════════════════════════════════════════════════════"
        echo
        echo "Domaine cible        : $DOMAIN"
        echo "Date/Heure           : $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "Version outil        : $VERSION"
        echo "Mode                 : $([ "$DEEP_SCAN" = true ] && echo "Deep Scan" || echo "Standard")"
        echo
        echo "═══════════════════════════════════════════════════════════════════"
        echo "                        STATISTIQUES GLOBALES                      "
        echo "═══════════════════════════════════════════════════════════════════"
        echo
        printf "%-30s : %d\n" "Total sous-domaines" "${STATS[total]}"
        printf "%-30s : %d\n" "Actifs (2xx)" "${STATS[active]}"
        printf "%-30s : %d\n" "Redirections (3xx)" "${STATS[redirects]}"
        printf "%-30s : %d\n" "Erreurs client (4xx)" "${STATS[errors_client]}"
        printf "%-30s : %d\n" "Erreurs serveur (5xx)" "${STATS[errors_server]}"
        printf "%-30s : %d\n" "Inactifs" "${STATS[inactive]}"
        
        if [ "$DEEP_SCAN" = true ]; then
            echo
            printf "%-30s : %d\n" "Avec WAF détecté" "${STATS[with_waf]}"
        fi
        
        echo
        echo "═══════════════════════════════════════════════════════════════════"
        echo "                    SOUS-DOMAINES DÉCOUVERTS                       "
        echo "═══════════════════════════════════════════════════════════════════"
        echo
        
        printf "%-35s | %-15s | %-10s | %-4s | %-5s | %-20s\n" \
            "SOUS-DOMAINE" "IP" "STATUT" "HTTP" "HTTPS" "SERVEUR"
        echo "──────────────────────────────────────────────────────────────────────────────────"
        
        sort -t'|' -k3,3r "$input_file" | while IFS='|' read -r sub ip status http https server waf; do
            printf "%-35s | %-15s | %-10s | %-4s | %-5s | %-20s\n" \
                "$sub" "$ip" "$status" "$http" "$https" "${server:0:20}"
        done
        
        echo
        echo "═══════════════════════════════════════════════════════════════════"
        echo "Fin du rapport - Généré par MSRSCRAP Expert v$VERSION"
        echo "═══════════════════════════════════════════════════════════════════"
        
    } > "$output_file"
    
    log SUCCESS "Rapport texte généré : $output_file"
}

generate_csv_report() {
    local input_file="$1"
    local output_file="$2"
    
    log INFO "Génération du rapport CSV..."
    
    {
        echo "subdomain,ip,status,http_code,https_code,server,waf"
        sed 's/|/,/g' "$input_file"
    } > "$output_file"
    
    log SUCCESS "Rapport CSV généré : $output_file"
}

generate_json_report() {
    local input_file="$1"
    local output_file="$2"
    
    log INFO "Génération du rapport JSON..."
    
    {
        echo "{"
        echo "  \"scan_info\": {"
        echo "    \"domain\": \"$DOMAIN\","
        echo "    \"timestamp\": \"$(date -Iseconds)\","
        echo "    \"version\": \"$VERSION\""
        echo "  },"
        echo "  \"statistics\": {"
        echo "    \"total\": ${STATS[total]},"
        echo "    \"active\": ${STATS[active]},"
        echo "    \"inactive\": ${STATS[inactive]},"
        echo "    \"redirects\": ${STATS[redirects]},"
        echo "    \"errors_client\": ${STATS[errors_client]},"
        echo "    \"errors_server\": ${STATS[errors_server]}"
        echo "  },"
        echo "  \"subdomains\": ["
        
        local first=true
        while IFS='|' read -r sub ip status http https server waf; do
            [ "$first" = true ] && first=false || echo ","
            echo "    {\"subdomain\": \"$sub\", \"ip\": \"$ip\", \"status\": \"$status\", \"http\": \"$http\", \"https\": \"$https\", \"server\": \"$server\", \"waf\": \"$waf\"}"
        done < "$input_file"
        
        echo "  ]"
        echo "}"
    } > "$output_file"
    
    log SUCCESS "Rapport JSON généré : $output_file"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    # Parse des arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain) DOMAIN="$2"; shift 2 ;;
            -t|--threads) THREADS="$2"; shift 2 ;;
            -D|--deep) DEEP_SCAN=true; shift ;;
            -s|--stealth) STEALTH_MODE=true; shift ;;
            --no-cache) USE_CACHE=false; shift ;;
            -o|--output) 
                OUTPUT_DIR="$2"
                CACHE_DIR="$OUTPUT_DIR/cache"
                REPORTS_DIR="$OUTPUT_DIR/reports"
                LOGS_DIR="$OUTPUT_DIR/logs"
                shift 2 
                ;;
            --json) EXPORT_JSON=true; shift ;;
            --html) EXPORT_HTML=true; shift ;;
            --csv) EXPORT_CSV=true; shift ;;
            --all-formats) EXPORT_JSON=true; EXPORT_HTML=true; EXPORT_CSV=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            --version) echo "MSRSCRAP Expert v$VERSION"; exit 0 ;;
            -h|--help) show_banner; usage; exit 0 ;;
            *) log ERROR "Option inconnue : $1"; usage; exit 1 ;;
        esac
    done
    
    # Vérifications
    if [ -z "$DOMAIN" ]; then
        show_banner
        log ERROR "Domaine requis !"
        echo
        usage
        exit 1
    fi
    
    # Démarrage
    show_banner
    
    log INFO "MSRSCRAP Expert v$VERSION"
    log INFO "═══════════════════════════════════════════"
    echo
    
    check_dependencies
    validate_domain "$DOMAIN"
    init_directories
    
    echo
    log INFO "Configuration du scan :"
    log INFO "  • Domaine    : $DOMAIN"
    log INFO "  • Threads    : $THREADS"
    log INFO "  • Mode       : $([ "$DEEP_SCAN" = true ] && echo "Deep Scan" || echo "Standard")"
    log INFO "  • Stealth    : $([ "$STEALTH_MODE" = true ] && echo "Activé" || echo "Désactivé")"
    log INFO "  • Cache      : $([ "$USE_CACHE" = true ] && echo "Activé" || echo "Désactivé")"
    echo
    
    check_wildcard
    echo
    
    # Énumération
    log INFO "═══════════════════════════════════════════"
    log INFO "PHASE 1 : ÉNUMÉRATION DES SOUS-DOMAINES"
    log INFO "═══════════════════════════════════════════"
    echo
    
    local subdomains_file=$(mktemp)
    enumerate_all_sources > "$subdomains_file"
    
    STATS[total]=$(wc -l < "$subdomains_file" | tr -d ' ')
    
    echo
    log INFO "═══════════════════════════════════════════"
    log INFO "PHASE 2 : ANALYSE DES SOUS-DOMAINES"
    log INFO "═══════════════════════════════════════════"
    echo
    
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local temp_results="$REPORTS_DIR/$DOMAIN/temp_results_$timestamp.tmp"
    
    > "$temp_results"
    
    # En-tête
    printf "\n${BOLD}%-35s %-15s %-12s %-10s %-25s${RESET}\n" \
        "SOUS-DOMAINE" "IP" "STATUT" "CODES" "SERVEUR"
    echo "$(printf '%*s' 100 '' | tr ' ' '─')"
    
    # Scan (avec ou sans parallel)
    if command -v parallel >/dev/null 2>&1; then
        export -f scan_subdomain resolve_ip test_http detect_server detect_waf get_random_ua rate_limit
        export DOMAIN TIMEOUT STEALTH_MODE DEEP_SCAN RATE_LIMIT_DELAY
        export VERT JAUNE ORANGE ROUGE BLANC BLEU CYAN RESET
        export -a USER_AGENTS
        export -A STATS
        
        cat "$subdomains_file" | parallel -j "$THREADS" scan_subdomain {} "$temp_results"
    else
        while read -r subdomain; do
            scan_subdomain "$subdomain" "$temp_results"
        done < "$subdomains_file"
    fi
    
    echo
    echo "$(printf '%*s' 100 '' | tr ' ' '─')"
    echo
    
    # Génération des rapports
    log INFO "═══════════════════════════════════════════"
    log INFO "PHASE 3 : GÉNÉRATION DES RAPPORTS"
    log INFO "═══════════════════════════════════════════"
    echo
    
    local report_base="$REPORTS_DIR/$DOMAIN/${DOMAIN}_${timestamp}"
    
    generate_text_report "$temp_results" "${report_base}.txt"
    [ "$EXPORT_CSV" = true ] && generate_csv_report "$temp_results" "${report_base}.csv"
    [ "$EXPORT_JSON" = true ] && generate_json_report "$temp_results" "${report_base}.json"
    
    # Nettoyage
    rm -f "$subdomains_file" "$temp_results"
    
    # Résumé final
    echo
    log SUCCESS "═══════════════════════════════════════════"
    log SUCCESS "SCAN TERMINÉ AVEC SUCCÈS !"
    log SUCCESS "═══════════════════════════════════════════"
    echo
    log INFO "📊 Statistiques finales :"
    log INFO "  • Total découvert    : ${STATS[total]}"
    log INFO "  • Actifs (2xx)       : ${VERT}${STATS[active]}${RESET}"
    log INFO "  • Redirections (3xx) : ${JAUNE}${STATS[redirects]}${RESET}"
    log INFO "  • Erreurs (4xx/5xx)  : ${ROUGE}$((${STATS[errors_client]} + ${STATS[errors_server]}))${RESET}"
    log INFO "  • Inactifs           : ${BLANC}${STATS[inactive]}${RESET}"
    
    if [ "$DEEP_SCAN" = true ]; then
        echo
        log INFO "🛡️  Détections avancées :"
        log INFO "  • WAF détectés       : ${STATS[with_waf]}"
    fi
    
    echo
    log INFO "📁 Rapports générés :"
    log INFO "  • Texte : ${report_base}.txt"
    [ "$EXPORT_CSV" = true ] && log INFO "  • CSV   : ${report_base}.csv"
    [ "$EXPORT_JSON" = true ] && log INFO "  • JSON  : ${report_base}.json"
    
    echo
    log SUCCESS "🎉 Reconnaissance terminée !"
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
