#!/bin/bash

# =============================================================================
# OUTIL EXPERT D'ÉNUMÉRATION DE SOUS-DOMAINES
# =============================================================================
# Version : 2.0 EXPERT
# Auteur : Advanced Reconnaissance Tool
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
declare -r TIMEOUT=8
declare -r RATE_LIMIT_DELAY=0.3
declare -r CACHE_VALIDITY=86400  # 24h en secondes

# Répertoires (modifiables via -o/--output)
OUTPUT_DIR="./output"
CACHE_DIR="$OUTPUT_DIR/cache"
REPORTS_DIR="$OUTPUT_DIR/reports"
LOGS_DIR="$OUTPUT_DIR/logs"

# User-Agents rotatifs
declare -a USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
)

# Variables globales
DOMAIN=""
THREADS=$MAX_THREADS
STEALTH_MODE=false
USE_CACHE=true
VERBOSE=false
DEEP_SCAN=false
API_KEYS_FILE="$SCRIPT_DIR/api_keys.conf"

# Statistiques
declare -A STATS=(
    [total]=0
    [active]=0
    [inactive]=0
    [redirects]=0
    [errors_client]=0
    [errors_server]=0
    [with_waf]=0
    [with_cdn]=0
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
    
    # Log vers fichier
    [ -d "$LOGS_DIR" ] && echo "[$timestamp] [$level] $message" >> "$LOGS_DIR/${DOMAIN}_scan.log"
}

get_random_ua() {
    echo "${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}"
}

rate_limit() {
    [ "$STEALTH_MODE" = true ] && sleep "$RATE_LIMIT_DELAY"
}

# =============================================================================
# BANNIÈRE ET AIDE
# =============================================================================

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
╔════════════════════════════════════════════════════════════════════════════════╗
║                                                                                ║
║   ███████╗██╗   ██╗██████╗ ██████╗  ██████╗ ███╗   ███╗ █████╗ ██╗███╗   ██╗   ║
║   ██╔════╝██║   ██║██╔══██╗██╔══██╗██╔═══██╗████╗ ████║██╔══██╗██║████╗  ██║   ║
║   ███████╗██║   ██║██████╔╝██║  ██║██║   ██║██╔████╔██║███████║██║██╔██╗ ██║   ║
║   ╚════██║██║   ██║██╔══██╗██║  ██║██║   ██║██║╚██╔╝██║██╔══██║██║██║╚██╗██║   ║
║   ███████║╚██████╔╝██████╔╝██████╔╝╚██████╔╝██║ ╚═╝ ██║██║  ██║██║██║ ╚████║   ║
║   ╚══════╝ ╚═════╝ ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝   ║
║                                                                                ║
║            ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗                         ║
║            ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║                         ║
║            ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║                         ║
║            ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║                         ║
║            ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║                         ║
║            ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝                         ║
║                                                                                ║
║                                                                                ║
║                  Advanced Subdomain Enumeration                                ║
║                                                                                ║
╚════════════════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${RESET}"
}

usage() {
    cat << EOF
${BOLD}UTILISATION :${RESET}
    $0 -d <domaine> [OPTIONS]

${BOLD}OPTIONS OBLIGATOIRES :${RESET}
    -d, --domain DOMAIN          Domaine cible à analyser

${BOLD}OPTIONS DE SCAN :${RESET}
    -t, --threads N              Nombre de threads (défaut: $MAX_THREADS)
    -D, --deep                   Mode scan approfondi (plus lent mais complet)
    -s, --stealth                Mode furtif avec délais et rotation UA
    --no-cache                   Désactiver le système de cache
    
${BOLD}OPTIONS D'EXPORT :${RESET}
    -o, --output DIR             Répertoire de sortie (défaut: $OUTPUT_DIR)
    --json                       Export JSON en plus du rapport
    --html                       Générer rapport HTML interactif
    --csv                        Export CSV
    --all-formats                Tous les formats d'export

${BOLD}OPTIONS AVANCÉES :${RESET}
    --api-keys FILE              Fichier de configuration des clés API
    --ports                      Scanner les ports communs
    --screenshots                Capturer des screenshots (nécessite wkhtmltoimage)
    --nuclei                     Lancer scan Nuclei sur les cibles actives
    
${BOLD}OPTIONS GÉNÉRALES :${RESET}
    -v, --verbose                Mode verbeux (debug)
    -h, --help                   Afficher cette aide
    --version                    Afficher la version

${BOLD}EXEMPLES :${RESET}
    # Scan basique
    $0 -d example.com
    
    # Scan expert complet
    $0 -d example.com --deep --stealth --all-formats --ports
    
    # Scan rapide avec cache désactivé
    $0 -d example.com -t 50 --no-cache
    
    # Scan avec export personnalisé
    $0 -d example.com -o /tmp/recon --json --html

${BOLD}CLÉS API (optionnelles mais recommandées) :${RESET}
    Créer un fichier api_keys.conf avec :
    VIRUSTOTAL_API_KEY=votre_clé
    SECURITYTRAILS_API_KEY=votre_clé
    SHODAN_API_KEY=votre_clé

EOF
}

# =============================================================================
# VÉRIFICATION DES DÉPENDANCES
# =============================================================================

check_dependencies() {
    log INFO "Vérification des dépendances..."
    
    local required_deps=("curl" "jq" "dig" "parallel")
    local optional_deps=("nmap" "wkhtmltoimage" "nuclei")
    local missing_required=()
    local missing_optional=()
    
    # Dépendances requises
    for dep in "${required_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_required+=("$dep")
        fi
    done
    
    if [ ${#missing_required[@]} -ne 0 ]; then
        log ERROR "Dépendances requises manquantes : ${missing_required[*]}"
        echo
        echo -e "${JAUNE}Installation suggérée :${RESET}"
        echo "  sudo apt-get install curl jq dnsutils parallel"
        echo "  # ou"
        echo "  sudo yum install curl jq bind-utils parallel"
        exit 1
    fi
    
    # Dépendances optionnelles
    for dep in "${optional_deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing_optional+=("$dep")
        fi
    done
    
    if [ ${#missing_optional[@]} -ne 0 ]; then
        log WARNING "Dépendances optionnelles manquantes : ${missing_optional[*]}"
        log INFO "Certaines fonctionnalités avancées seront désactivées"
    fi
    
    log SUCCESS "Toutes les dépendances requises sont installées"
}

# =============================================================================
# VALIDATION ET INITIALISATION
# =============================================================================

validate_domain() {
    local domain="$1"
    
    # Validation basique du format
    if ! [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        log ERROR "Format de domaine invalide : $domain"
        exit 1
    fi
    
    # Vérifier que le domaine existe (résolution DNS)
    if ! dig +short "$domain" A >/dev/null 2>&1 && ! dig +short "$domain" AAAA >/dev/null 2>&1; then
        log WARNING "Impossible de résoudre le domaine : $domain"
        read -p "Continuer quand même ? (o/N) " -n 1 -r
        echo
        [[ ! $REPLY =~ ^[Oo]$ ]] && exit 1
    fi
    
    log SUCCESS "Domaine validé : $domain"
}

init_directories() {
    log INFO "Initialisation des répertoires..."
    
    mkdir -p "$OUTPUT_DIR" "$CACHE_DIR" "$REPORTS_DIR" "$LOGS_DIR"
    
    # Créer sous-répertoire pour ce domaine
    mkdir -p "$REPORTS_DIR/$DOMAIN"
    mkdir -p "$CACHE_DIR/$DOMAIN"
    
    log SUCCESS "Répertoires créés"
}

load_api_keys() {
    if [ -f "$API_KEYS_FILE" ]; then
        log INFO "Chargement des clés API depuis $API_KEYS_FILE"
        source "$API_KEYS_FILE"
        
        [ -n "${VIRUSTOTAL_API_KEY:-}" ] && log SUCCESS "VirusTotal API détectée"
        [ -n "${SECURITYTRAILS_API_KEY:-}" ] && log SUCCESS "SecurityTrails API détectée"
        [ -n "${SHODAN_API_KEY:-}" ] && log SUCCESS "Shodan API détectée"
    else
        log WARNING "Fichier de clés API non trouvé : $API_KEYS_FILE"
        log INFO "Les scans seront effectués sans les API payantes"
    fi
}

# =============================================================================
# SYSTÈME DE CACHE
# =============================================================================

get_cache_file() {
    local key="$1"
    local hash=$(echo -n "$key" | md5sum | cut -d' ' -f1)
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
        
        if [ $cache_age -lt $CACHE_VALIDITY ]; then
            log DEBUG "Utilisation du cache pour : $key"
            cat "$cache_file"
            return 0
        else
            log DEBUG "Cache expiré pour : $key"
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
    log INFO "Vérification des wildcards DNS..."
    
    local random_sub="random-nonexistent-subdomain-$(date +%s%N)"
    local wildcard_ip=$(dig +short "${random_sub}.${DOMAIN}" A 2>/dev/null | head -n 1)
    
    if [ -n "$wildcard_ip" ] && [[ "$wildcard_ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log WARNING "WILDCARD DNS DÉTECTÉ ! (Résout vers : $wildcard_ip)"
        log WARNING "Les résultats peuvent contenir de nombreux faux positifs"
        echo "$wildcard_ip" > "$CACHE_DIR/$DOMAIN/wildcard.txt"
        return 0
    fi
    
    log SUCCESS "Pas de wildcard DNS détecté"
    return 1
}

# =============================================================================
# ÉNUMÉRATION MULTI-SOURCES
# =============================================================================

enumerate_crtsh() {
    log INFO "Énumération via crt.sh..."
    
    if use_cache "crtsh_$DOMAIN"; then
        return 0
    fi
    
    local results=$(curl -s "https://crt.sh/?q=%25.$DOMAIN&output=json" 2>/dev/null | \
        jq -r '.[].name_value' 2>/dev/null | \
        sed 's/\*\.//g' | \
        sort -u | \
        grep -E "^[a-zA-Z0-9.-]+\.$DOMAIN$" || true)
    
    local count=$(echo "$results" | grep -c . || echo 0)
    
    if [ $count -gt 0 ]; then
        log SUCCESS "crt.sh : $count sous-domaines trouvés"
        save_cache "crtsh_$DOMAIN" "$results"
        echo "$results"
    else
        log WARNING "crt.sh : Aucun résultat"
    fi
}

enumerate_certspotter() {
    log INFO "Énumération via CertSpotter..."
    
    if use_cache "certspotter_$DOMAIN"; then
        return 0
    fi
    
    local results=$(curl -s "https://api.certspotter.com/v1/issuances?domain=$DOMAIN&include_subdomains=true&expand=dns_names" 2>/dev/null | \
        jq -r '.[].dns_names[]' 2>/dev/null | \
        sort -u | \
        grep -E "^[a-zA-Z0-9.-]+\.$DOMAIN$" || true)
    
    local count=$(echo "$results" | grep -c . || echo 0)
    
    if [ $count -gt 0 ]; then
        log SUCCESS "CertSpotter : $count sous-domaines trouvés"
        save_cache "certspotter_$DOMAIN" "$results"
        echo "$results"
    else
        log WARNING "CertSpotter : Aucun résultat"
    fi
}

enumerate_threatcrowd() {
    log INFO "Énumération via ThreatCrowd..."
    
    if use_cache "threatcrowd_$DOMAIN"; then
        return 0
    fi
    
    rate_limit
    
    local results=$(curl -s "https://www.threatcrowd.org/searchApi/v2/domain/report/?domain=$DOMAIN" 2>/dev/null | \
        jq -r '.subdomains[]?' 2>/dev/null | \
        sort -u | \
        grep -E "^[a-zA-Z0-9.-]+\.$DOMAIN$" || true)
    
    local count=$(echo "$results" | grep -c . || echo 0)
    
    if [ $count -gt 0 ]; then
        log SUCCESS "ThreatCrowd : $count sous-domaines trouvés"
        save_cache "threatcrowd_$DOMAIN" "$results"
        echo "$results"
    else
        log WARNING "ThreatCrowd : Aucun résultat"
    fi
}

enumerate_hackertarget() {
    log INFO "Énumération via HackerTarget..."
    
    if use_cache "hackertarget_$DOMAIN"; then
        return 0
    fi
    
    rate_limit
    
    local results=$(curl -s "https://api.hackertarget.com/hostsearch/?q=$DOMAIN" 2>/dev/null | \
        cut -d',' -f1 | \
        sort -u | \
        grep -E "^[a-zA-Z0-9.-]+\.$DOMAIN$" || true)
    
    local count=$(echo "$results" | grep -c . || echo 0)
    
    if [ $count -gt 0 ]; then
        log SUCCESS "HackerTarget : $count sous-domaines trouvés"
        save_cache "hackertarget_$DOMAIN" "$results"
        echo "$results"
    else
        log WARNING "HackerTarget : Aucun résultat"
    fi
}

enumerate_alienvault() {
    log INFO "Énumération via AlienVault OTX..."
    
    if use_cache "alienvault_$DOMAIN"; then
        return 0
    fi
    
    rate_limit
    
    local results=$(curl -s "https://otx.alienvault.com/api/v1/indicators/domain/$DOMAIN/passive_dns" 2>/dev/null | \
        jq -r '.passive_dns[].hostname' 2>/dev/null | \
        sort -u | \
        grep -E "^[a-zA-Z0-9.-]+\.$DOMAIN$" || true)
    
    local count=$(echo "$results" | grep -c . || echo 0)
    
    if [ $count -gt 0 ]; then
        log SUCCESS "AlienVault : $count sous-domaines trouvés"
        save_cache "alienvault_$DOMAIN" "$results"
        echo "$results"
    else
        log WARNING "AlienVault : Aucun résultat"
    fi
}

enumerate_urlscan() {
    log INFO "Énumération via URLScan.io..."
    
    if use_cache "urlscan_$DOMAIN"; then
        return 0
    fi
    
    rate_limit
    
    local results=$(curl -s "https://urlscan.io/api/v1/search/?q=domain:$DOMAIN" 2>/dev/null | \
        jq -r '.results[].page.domain' 2>/dev/null | \
        sort -u | \
        grep -E "^[a-zA-Z0-9.-]+\.$DOMAIN$" || true)
    
    local count=$(echo "$results" | grep -c . || echo 0)
    
    if [ $count -gt 0 ]; then
        log SUCCESS "URLScan : $count sous-domaines trouvés"
        save_cache "urlscan_$DOMAIN" "$results"
        echo "$results"
    else
        log WARNING "URLScan : Aucun résultat"
    fi
}

enumerate_virustotal() {
    if [ -z "${VIRUSTOTAL_API_KEY:-}" ]; then
        log DEBUG "VirusTotal : API key non configurée, ignoré"
        return 0
    fi
    
    log INFO "Énumération via VirusTotal..."
    
    if use_cache "virustotal_$DOMAIN"; then
        return 0
    fi
    
    rate_limit
    
    local results=$(curl -s -H "x-apikey: $VIRUSTOTAL_API_KEY" \
        "https://www.virustotal.com/api/v3/domains/$DOMAIN/subdomains?limit=40" 2>/dev/null | \
        jq -r '.data[].id' 2>/dev/null | \
        sort -u | \
        grep -E "^[a-zA-Z0-9.-]+\.$DOMAIN$" || true)
    
    local count=$(echo "$results" | grep -c . || echo 0)
    
    if [ $count -gt 0 ]; then
        log SUCCESS "VirusTotal : $count sous-domaines trouvés"
        save_cache "virustotal_$DOMAIN" "$results"
        echo "$results"
    else
        log WARNING "VirusTotal : Aucun résultat"
    fi
}

enumerate_all_sources() {
    log INFO "Démarrage de l'énumération multi-sources..."
    echo
    
    local temp_file=$(mktemp)
    
    # Lancer toutes les sources en parallèle
    {
        enumerate_crtsh
        enumerate_certspotter
        enumerate_threatcrowd
        enumerate_hackertarget
        enumerate_alienvault
        enumerate_urlscan
        enumerate_virustotal
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
    
    # IPv4
    local ipv4=$(dig +short "$subdomain" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1)
    
    # IPv6 (si deep scan)
    local ipv6=""
    if [ "$DEEP_SCAN" = true ]; then
        ipv6=$(dig +short "$subdomain" AAAA 2>/dev/null | head -n 1)
    fi
    
    if [ -n "$ipv4" ]; then
        echo "$ipv4"
    elif [ -n "$ipv6" ]; then
        echo "$ipv6"
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

detect_waf_cdn() {
    local subdomain="$1"
    local ua=$(get_random_ua)
    local waf="N/A"
    local cdn="N/A"
    
    local headers=$(curl -I -s --max-time "$TIMEOUT" -A "$ua" -k "https://$subdomain" 2>/dev/null)
    
    # Détection WAF
    if echo "$headers" | grep -qi "cloudflare\|cf-ray"; then
        waf="Cloudflare"
        cdn="Cloudflare"
    elif echo "$headers" | grep -qi "x-sucuri-id\|sucuri"; then
        waf="Sucuri"
    elif echo "$headers" | grep -qi "imperva\|incapsula\|x-iinfo"; then
        waf="Imperva"
    elif echo "$headers" | grep -qi "akamai"; then
        waf="Akamai"
        cdn="Akamai"
    elif echo "$headers" | grep -qi "x-amz-cf-id"; then
        cdn="CloudFront"
    elif echo "$headers" | grep -qi "fastly"; then
        cdn="Fastly"
    fi
    
    echo "$waf|$cdn"
}

detect_technologies() {
    local subdomain="$1"
    local ua=$(get_random_ua)
    local techs=()
    
    local headers=$(curl -I -s --max-time "$TIMEOUT" -A "$ua" -k "http://$subdomain" 2>/dev/null)
    
    echo "$headers" | grep -qi "x-powered-by.*php" && techs+=("PHP")
    echo "$headers" | grep -qi "x-aspnet-version" && techs+=("ASP.NET")
    echo "$headers" | grep -qi "x-drupal" && techs+=("Drupal")
    echo "$headers" | grep -qi "x-wordpress\|wp-" && techs+=("WordPress")
    
    if [ ${#techs[@]} -eq 0 ]; then
        echo "N/A"
    else
        echo "${techs[*]}" | tr ' ' ','
    fi
}

get_page_title() {
    local url="$1"
    local ua=$(get_random_ua)
    
    local title=$(curl -L -s --max-time "$TIMEOUT" -A "$ua" -k "$url" 2>/dev/null | \
        grep -oPm1 "(?<=<title>)[^<]+" 2>/dev/null | head -c 50)
    
    [ -z "$title" ] && title="N/A"
    echo "$title"
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
    
    # Informations supplémentaires pour les cibles actives
    local server="N/A"
    local waf="N/A"
    local cdn="N/A"
    local tech="N/A"
    local title="N/A"
    
    if [ "$status" = "ACTIVE" ] || [ "$DEEP_SCAN" = true ]; then
        server=$(detect_server "$subdomain")
        
        if [ "$DEEP_SCAN" = true ]; then
            local waf_cdn=$(detect_waf_cdn "$subdomain")
            waf=$(echo "$waf_cdn" | cut -d'|' -f1)
            cdn=$(echo "$waf_cdn" | cut -d'|' -f2)
            tech=$(detect_technologies "$subdomain")
            
            [ "$waf" != "N/A" ] && ((STATS[with_waf]++))
            [ "$cdn" != "N/A" ] && ((STATS[with_cdn]++))
            
            # Titre de la page
            if [[ "$https_code" =~ ^2 ]]; then
                title=$(get_page_title "https://$subdomain")
            elif [[ "$http_code" =~ ^2 ]]; then
                title=$(get_page_title "http://$subdomain")
            fi
        fi
    fi
    
    # Affichage temps réel
    printf "${couleur}[+]${RESET} %-35s ${CYAN}%-15s${RESET} %-12s ${JAUNE}%-4s${RESET}/${VERT}%-4s${RESET} %-20s\n" \
        "$subdomain" "$ip" "$status" "$http_code" "$https_code" "${server:0:20}"
    
    # Sauvegarde
    printf "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n" \
        "$subdomain" "$ip" "$status" "$http_code" "$https_code" "$server" "$waf" "$cdn" "$tech" "$title" \
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
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo "                    RAPPORT D'ÉNUMÉRATION DE SOUS-DOMAINES                 "
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo
        echo "Domaine cible        : $DOMAIN"
        echo "Date/Heure           : $(date '+%Y-%m-%d %H:%M:%S %Z')"
        echo "Version outil        : $VERSION"
        echo "Mode                 : $([ "$DEEP_SCAN" = true ] && echo "Deep Scan" || echo "Standard")"
        echo "Stealth              : $([ "$STEALTH_MODE" = true ] && echo "Activé" || echo "Désactivé")"
        echo "Threads              : $THREADS"
        echo
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo "                              STATISTIQUES GLOBALES                        "
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo
        printf "%-30s : %d\n" "Total sous-domaines" "${STATS[total]}"
        printf "%-30s : %d (%.1f%%)\n" "Actifs (2xx)" "${STATS[active]}" \
            $(echo "scale=1; ${STATS[active]} * 100 / ${STATS[total]}" | bc 2>/dev/null || echo "0.0")
        printf "%-30s : %d (%.1f%%)\n" "Redirections (3xx)" "${STATS[redirects]}" \
            $(echo "scale=1; ${STATS[redirects]} * 100 / ${STATS[total]}" | bc 2>/dev/null || echo "0.0")
        printf "%-30s : %d (%.1f%%)\n" "Erreurs client (4xx)" "${STATS[errors_client]}" \
            $(echo "scale=1; ${STATS[errors_client]} * 100 / ${STATS[total]}" | bc 2>/dev/null || echo "0.0")
        printf "%-30s : %d (%.1f%%)\n" "Erreurs serveur (5xx)" "${STATS[errors_server]}" \
            $(echo "scale=1; ${STATS[errors_server]} * 100 / ${STATS[total]}" | bc 2>/dev/null || echo "0.0")
        printf "%-30s : %d (%.1f%%)\n" "Inactifs" "${STATS[inactive]}" \
            $(echo "scale=1; ${STATS[inactive]} * 100 / ${STATS[total]}" | bc 2>/dev/null || echo "0.0")
        
        if [ "$DEEP_SCAN" = true ]; then
            echo
            printf "%-30s : %d\n" "Avec WAF détecté" "${STATS[with_waf]}"
            printf "%-30s : %d\n" "Avec CDN détecté" "${STATS[with_cdn]}"
        fi
        
        echo
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo "                         SOUS-DOMAINES DÉCOUVERTS                          "
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo
        
        if [ "$DEEP_SCAN" = true ]; then
            printf "%-35s | %-15s | %-10s | %-4s | %-5s | %-15s | %-12s | %-12s\n" \
                "SOUS-DOMAINE" "IP" "STATUT" "HTTP" "HTTPS" "SERVEUR" "WAF" "CDN"
            echo "───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"
        else
            printf "%-35s | %-15s | %-10s | %-4s | %-5s | %-20s\n" \
                "SOUS-DOMAINE" "IP" "STATUT" "HTTP" "HTTPS" "SERVEUR"
            echo "─────────────────────────────────────────────────────────────────────────────────────────────────"
        fi
        
        # Trier par statut (ACTIVE en premier)
        sort -t'|' -k3,3r "$input_file" | while IFS='|' read -r sub ip status http https server waf cdn tech title; do
            if [ "$DEEP_SCAN" = true ]; then
                printf "%-35s | %-15s | %-10s | %-4s | %-5s | %-15s | %-12s | %-12s\n" \
                    "$sub" "$ip" "$status" "$http" "$https" "${server:0:15}" "$waf" "$cdn"
            else
                printf "%-35s | %-15s | %-10s | %-4s | %-5s | %-20s\n" \
                    "$sub" "$ip" "$status" "$http" "$https" "${server:0:20}"
            fi
        done
        
        echo
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo "                            TOP SOUS-DOMAINES ACTIFS                       "
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo
        
        grep "|ACTIVE|" "$input_file" | head -20 | while IFS='|' read -r sub ip status http https server waf cdn tech title; do
            echo "• $sub"
            echo "  └─ IP: $ip | Serveur: $server"
            [ "$DEEP_SCAN" = true ] && [ "$title" != "N/A" ] && echo "  └─ Titre: $title"
            echo
        done
        
        echo "═══════════════════════════════════════════════════════════════════════════"
        echo "Fin du rapport - Généré par Subdomain Recon Expert v$VERSION"
        echo "═══════════════════════════════════════════════════════════════════════════"
        
    } > "$output_file"
    
    log SUCCESS "Rapport texte généré : $output_file"
}

generate_csv_report() {
    local input_file="$1"
    local output_file="$2"
    
    log INFO "Génération du rapport CSV..."
    
    {
        if [ "$DEEP_SCAN" = true ]; then
            echo "subdomain,ip,status,http_code,https_code,server,waf,cdn,technologies,title"
        else
            echo "subdomain,ip,status,http_code,https_code,server"
        fi
        
        if [ "$DEEP_SCAN" = true ]; then
            sed 's/|/,/g' "$input_file"
        else
            cut -d'|' -f1-6 "$input_file" | sed 's/|/,/g'
        fi
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
        echo "    \"version\": \"$VERSION\","
        echo "    \"deep_scan\": $([ "$DEEP_SCAN" = true ] && echo "true" || echo "false"),"
        echo "    \"stealth_mode\": $([ "$STEALTH_MODE" = true ] && echo "true" || echo "false"),"
        echo "    \"threads\": $THREADS"
        echo "  },"
        echo "  \"statistics\": {"
        echo "    \"total\": ${STATS[total]},"
        echo "    \"active\": ${STATS[active]},"
        echo "    \"inactive\": ${STATS[inactive]},"
        echo "    \"redirects\": ${STATS[redirects]},"
        echo "    \"errors_client\": ${STATS[errors_client]},"
        echo "    \"errors_server\": ${STATS[errors_server]},"
        echo "    \"with_waf\": ${STATS[with_waf]},"
        echo "    \"with_cdn\": ${STATS[with_cdn]}"
        echo "  },"
        echo "  \"subdomains\": ["
        
        local first=true
        while IFS='|' read -r sub ip status http https server waf cdn tech title; do
            [ "$first" = true ] && first=false || echo ","
            
            cat <<EOF
    {
      "subdomain": "$sub",
      "ip": "$ip",
      "status": "$status",
      "http_code": "$http",
      "https_code": "$https",
      "server": "$server",
      "waf": "$waf",
      "cdn": "$cdn",
      "technologies": "$tech",
      "title": "$title"
    }
EOF
        done < "$input_file"
        
        echo "  ]"
        echo "}"
    } > "$output_file"
    
    log SUCCESS "Rapport JSON généré : $output_file"
}

generate_html_report() {
    local input_file="$1"
    local output_file="$2"
    
    log INFO "Génération du rapport HTML..."
    
    cat > "$output_file" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rapport d'Énumération - SUBDOMAIN_PLACEHOLDER</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { 
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; 
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            padding: 20px;
            color: #333;
        }
        .container {
            max-width: 1600px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }
        .header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            text-align: center;
        }
        .header h1 {
            font-size: 2.5em;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }
        .header .subtitle {
            font-size: 1.2em;
            opacity: 0.9;
        }
        .stats {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 20px;
            padding: 30px;
            background: #f8f9fa;
        }
        .stat-box {
            background: white;
            padding: 25px;
            border-radius: 10px;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            text-align: center;
            transition: transform 0.3s;
        }
        .stat-box:hover {
            transform: translateY(-5px);
            box-shadow: 0 6px 12px rgba(0,0,0,0.15);
        }
        .stat-box h3 {
            color: #666;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
            margin-bottom: 10px;
        }
        .stat-box .number {
            font-size: 2.5em;
            font-weight: bold;
            color: #667eea;
        }
        .stat-box.active .number { color: #27ae60; }
        .stat-box.inactive .number { color: #95a5a6; }
        .stat-box.error .number { color: #e74c3c; }
        
        .content {
            padding: 30px;
        }
        .search-box {
            margin-bottom: 25px;
        }
        .search-box input {
            width: 100%;
            padding: 15px 20px;
            font-size: 16px;
            border: 2px solid #ddd;
            border-radius: 8px;
            transition: border-color 0.3s;
        }
        .search-box input:focus {
            outline: none;
            border-color: #667eea;
        }
        .filters {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
            flex-wrap: wrap;
        }
        .filter-btn {
            padding: 10px 20px;
            border: 2px solid #667eea;
            background: white;
            color: #667eea;
            border-radius: 20px;
            cursor: pointer;
            transition: all 0.3s;
            font-weight: 600;
        }
        .filter-btn:hover, .filter-btn.active {
            background: #667eea;
            color: white;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            background: white;
            box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            border-radius: 8px;
            overflow: hidden;
        }
        thead {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        th {
            padding: 15px;
            text-align: left;
            font-weight: 600;
            text-transform: uppercase;
            font-size: 0.85em;
            letter-spacing: 1px;
        }
        td {
            padding: 12px 15px;
            border-bottom: 1px solid #f0f0f0;
        }
        tr:hover {
            background: #f8f9fa;
        }
        .status-badge {
            display: inline-block;
            padding: 5px 12px;
            border-radius: 20px;
            font-size: 0.85em;
            font-weight: 600;
            text-transform: uppercase;
        }
        .status-active { background: #d4edda; color: #155724; }
        .status-inactive { background: #e2e3e5; color: #383d41; }
        .status-redirect { background: #fff3cd; color: #856404; }
        .status-error { background: #f8d7da; color: #721c24; }
        
        .code-ok { color: #27ae60; font-weight: bold; }
        .code-redirect { color: #f39c12; font-weight: bold; }
        .code-error { color: #e74c3c; font-weight: bold; }
        .code-none { color: #95a5a6; }
        
        .footer {
            padding: 20px;
            text-align: center;
            background: #f8f9fa;
            color: #666;
            border-top: 1px solid #dee2e6;
        }
        
        @media (max-width: 768px) {
            .stats { grid-template-columns: 1fr; }
            table { font-size: 0.85em; }
            th, td { padding: 8px; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🔍 Rapport d'Énumération</h1>
            <p class="subtitle">SUBDOMAIN_PLACEHOLDER</p>
            <p style="margin-top: 10px; font-size: 0.9em;">TIMESTAMP_PLACEHOLDER</p>
        </div>
        
        <div class="stats">
            <div class="stat-box">
                <h3>Total</h3>
                <div class="number" id="stat-total">0</div>
            </div>
            <div class="stat-box active">
                <h3>Actifs</h3>
                <div class="number" id="stat-active">0</div>
            </div>
            <div class="stat-box inactive">
                <h3>Inactifs</h3>
                <div class="number" id="stat-inactive">0</div>
            </div>
            <div class="stat-box">
                <h3>Redirections</h3>
                <div class="number" id="stat-redirect">0</div>
            </div>
            <div class="stat-box error">
                <h3>Erreurs</h3>
                <div class="number" id="stat-error">0</div>
            </div>
        </div>
        
        <div class="content">
            <div class="search-box">
                <input type="text" id="searchInput" placeholder="🔍 Rechercher un sous-domaine, une IP, un serveur...">
            </div>
            
            <div class="filters">
                <button class="filter-btn active" data-filter="all">Tous</button>
                <button class="filter-btn" data-filter="ACTIVE">Actifs</button>
                <button class="filter-btn" data-filter="INACTIVE">Inactifs</button>
                <button class="filter-btn" data-filter="REDIRECT">Redirections</button>
                <button class="filter-btn" data-filter="ERROR">Erreurs</button>
            </div>
            
            <table id="resultsTable">
                <thead>
                    <tr>
                        <th>Sous-domaine</th>
                        <th>IP</th>
                        <th>Statut</th>
                        <th>HTTP</th>
                        <th>HTTPS</th>
                        <th>Serveur</th>
                        <th>WAF/CDN</th>
                    </tr>
                </thead>
                <tbody id="tableBody">
                    <!-- DATA_PLACEHOLDER -->
                </tbody>
            </table>
        </div>
        
        <div class="footer">
            <p><strong>Subdomain Recon Expert v2.0</strong></p>
            <p>Généré le TIMESTAMP_PLACEHOLDER</p>
        </div>
    </div>
    
    <script>
        // Données
        const data = [
            // JSON_DATA_PLACEHOLDER
        ];
        
        let filteredData = [...data];
        
        // Fonctions utilitaires
        function getStatusClass(status) {
            if (status === 'ACTIVE') return 'status-active';
            if (status === 'INACTIVE') return 'status-inactive';
            if (status === 'REDIRECT') return 'status-redirect';
            return 'status-error';
        }
        
        function getCodeClass(code) {
            if (code >= 200 && code < 300) return 'code-ok';
            if (code >= 300 && code < 400) return 'code-redirect';
            if (code >= 400) return 'code-error';
            return 'code-none';
        }
        
        // Rendu du tableau
        function renderTable(data) {
            const tbody = document.getElementById('tableBody');
            tbody.innerHTML = '';
            
            data.forEach(item => {
                const row = document.createElement('tr');
                row.innerHTML = `
                    <td><strong>${item.subdomain}</strong></td>
                    <td>${item.ip}</td>
                    <td><span class="status-badge ${getStatusClass(item.status)}">${item.status}</span></td>
                    <td><span class="${getCodeClass(item.http_code)}">${item.http_code}</span></td>
                    <td><span class="${getCodeClass(item.https_code)}">${item.https_code}</span></td>
                    <td>${item.server}</td>
                    <td>${item.waf !== 'N/A' ? item.waf : ''} ${item.cdn !== 'N/A' ? '/ ' + item.cdn : ''}</td>
                `;
                tbody.appendChild(row);
            });
        }
        
        // Mise à jour des statistiques
        function updateStats() {
            document.getElementById('stat-total').textContent = data.length;
            document.getElementById('stat-active').textContent = data.filter(d => d.status === 'ACTIVE').length;
            document.getElementById('stat-inactive').textContent = data.filter(d => d.status === 'INACTIVE').length;
            document.getElementById('stat-redirect').textContent = data.filter(d => d.status === 'REDIRECT').length;
            document.getElementById('stat-error').textContent = data.filter(d => d.status.includes('ERROR')).length;
        }
        
        // Recherche
        document.getElementById('searchInput').addEventListener('input', function(e) {
            const searchTerm = e.target.value.toLowerCase();
            filteredData = data.filter(item => 
                item.subdomain.toLowerCase().includes(searchTerm) ||
                item.ip.toLowerCase().includes(searchTerm) ||
                item.server.toLowerCase().includes(searchTerm)
            );
            renderTable(filteredData);
        });
        
        // Filtres
        document.querySelectorAll('.filter-btn').forEach(btn => {
            btn.addEventListener('click', function() {
                document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
                this.classList.add('active');
                
                const filter = this.dataset.filter;
                if (filter === 'all') {
                    filteredData = [...data];
                } else if (filter === 'ERROR') {
                    filteredData = data.filter(d => d.status.includes('ERROR'));
                } else {
                    filteredData = data.filter(d => d.status === filter);
                }
                renderTable(filteredData);
            });
        });
        
        // Initialisation
        updateStats();
        renderTable(data);
    </script>
</body>
</html>
HTMLEOF
    
    # Remplacer les placeholders
    sed -i "s/SUBDOMAIN_PLACEHOLDER/$DOMAIN/g" "$output_file"
    sed -i "s/TIMESTAMP_PLACEHOLDER/$(date '+%Y-%m-%d %H:%M:%S')/g" "$output_file"
    
    # Générer les données JSON pour le HTML
    local json_data=""
    local first=true
    while IFS='|' read -r sub ip status http https server waf cdn tech title; do
        [ "$first" = true ] && first=false || json_data+=","
        json_data+="{\"subdomain\":\"$sub\",\"ip\":\"$ip\",\"status\":\"$status\",\"http_code\":\"$http\",\"https_code\":\"$https\",\"server\":\"$server\",\"waf\":\"$waf\",\"cdn\":\"$cdn\"}"
    done < "$input_file"
    
    sed -i "s|// JSON_DATA_PLACEHOLDER|$json_data|g" "$output_file"
    
    log SUCCESS "Rapport HTML généré : $output_file"
}

# =============================================================================
# FONCTION PRINCIPALE
# =============================================================================

main() {
    local export_json=false
    local export_html=false
    local export_csv=false
    
    # Parse des arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--domain)
                DOMAIN="$2"
                shift 2
                ;;
            -t|--threads)
                THREADS="$2"
                shift 2
                ;;
            -D|--deep)
                DEEP_SCAN=true
                shift
                ;;
            -s|--stealth)
                STEALTH_MODE=true
                shift
                ;;
            --no-cache)
                USE_CACHE=false
                shift
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                # Reconstruire les chemins des sous-répertoires
                CACHE_DIR="$OUTPUT_DIR/cache"
                REPORTS_DIR="$OUTPUT_DIR/reports"
                LOGS_DIR="$OUTPUT_DIR/logs"
                shift 2
                ;;
            --json)
                export_json=true
                shift
                ;;
            --html)
                export_html=true
                shift
                ;;
            --csv)
                export_csv=true
                shift
                ;;
            --all-formats)
                export_json=true
                export_html=true
                export_csv=true
                shift
                ;;
            --api-keys)
                API_KEYS_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --version)
                echo "Subdomain Recon Expert v$VERSION"
                exit 0
                ;;
            -h|--help)
                show_banner
                usage
                exit 0
                ;;
            *)
                log ERROR "Option inconnue : $1"
                usage
                exit 1
                ;;
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
    
    log INFO "Subdomain Recon Expert v$VERSION"
    log INFO "═══════════════════════════════════════════"
    echo
    
    check_dependencies
    validate_domain "$DOMAIN"
    init_directories
    load_api_keys
    
    echo
    log INFO "Configuration du scan :"
    log INFO "  • Domaine    : $DOMAIN"
    log INFO "  • Threads    : $THREADS"
    log INFO "  • Mode       : $([ "$DEEP_SCAN" = true ] && echo "Deep Scan ⚡" || echo "Standard 🚀")"
    log INFO "  • Stealth    : $([ "$STEALTH_MODE" = true ] && echo "Activé 🥷" || echo "Désactivé")"
    log INFO "  • Cache      : $([ "$USE_CACHE" = true ] && echo "Activé 💾" || echo "Désactivé")"
    echo
    
    # Vérification wildcard
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
    
    # Export des fonctions pour parallel
    export -f scan_subdomain resolve_ip test_http detect_server detect_waf_cdn detect_technologies get_page_title get_random_ua rate_limit log
    export DOMAIN TIMEOUT STEALTH_MODE DEEP_SCAN RATE_LIMIT_DELAY LOGS_DIR
    export VERT JAUNE ORANGE ROUGE BLANC BLEU CYAN RESET
    export -a USER_AGENTS
    export -A STATS
    
    # Scan parallèle
    cat "$subdomains_file" | parallel -j "$THREADS" --bar scan_subdomain {} "$temp_results"
    
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
    
    [ "$export_csv" = true ] && generate_csv_report "$temp_results" "${report_base}.csv"
    [ "$export_json" = true ] && generate_json_report "$temp_results" "${report_base}.json"
    [ "$export_html" = true ] && generate_html_report "$temp_results" "${report_base}.html"
    
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
        log INFO "  • CDN détectés       : ${STATS[with_cdn]}"
    fi
    
    echo
    log INFO "📁 Rapports générés :"
    log INFO "  • Texte : ${report_base}.txt"
    [ "$export_csv" = true ] && log INFO "  • CSV   : ${report_base}.csv"
    [ "$export_json" = true ] && log INFO "  • JSON  : ${report_base}.json"
    [ "$export_html" = true ] && log INFO "  • HTML  : ${report_base}.html"
    
    echo
    log SUCCESS "🎉 Reconnaissance terminée !"
}

# Point d'entrée
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
