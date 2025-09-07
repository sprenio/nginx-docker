#!/usr/bin/env bash
set -e

# Katalog nadrzędny względem skryptu
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Domyślne ścieżki
DEFAULT_LETSENCRYPT_DIR="$PROJECT_DIR/letsencrypt/etc"
DEFAULT_CHALLENGE_DIR="$PROJECT_DIR/letsencrypt/data"
LOG_DIR="$PROJECT_DIR/logs"

# Wczytanie .env, jeśli istnieje w katalogu projektu
if [[ -f "$PROJECT_DIR/.env" ]]; then
    export $(grep -v '^#' "$PROJECT_DIR/.env" | xargs)
fi

LETSENCRYPT_DIR="${LETSENCRYPT_DIR:-$DEFAULT_LETSENCRYPT_DIR}"
CHALLENGE_DIR="${CHALLENGE_DIR:-$DEFAULT_CHALLENGE_DIR}"

# Tworzymy katalog logów
mkdir -p "$LOG_DIR"

# Plik logu z datą i godziną
LOG_FILE="$LOG_DIR/certbot_$(date +'%Y%m%d_%H%M%S').log"

# Funkcja pokazująca użycie
usage() {
    echo "Usage: $0 -d domain1,domain2 -e email@example.com [-r]"
    echo "  -d  Comma-separated list of domains (ignored in renew-all mode)"
    echo "  -e  Email address for notifications"
    echo "  -r  Renew all existing certificates"
    exit 1
}

# Parsowanie parametrów
RENEW=false
while getopts "d:e:rx:" opt; do
    case $opt in
        d) DOMAINS="$OPTARG" ;;
        e) EMAIL="$OPTARG" ;;
        r) RENEW=true ;;
        x) DELETE_DOMAINS="$OPTARG" ;;
        *) usage ;;
    esac
done


# Wymagany email zawsze
if [[ -z "$EMAIL" ]]; then
    echo "Error: missing email parameter."
    usage
fi

# Tworzymy katalogi, jeśli nie istnieją
mkdir -p "$LETSENCRYPT_DIR"
mkdir -p "$CHALLENGE_DIR"

# Funkcja do odnowienia wszystkich certyfikatów w katalogu live/
renew_all_certs() {
    echo "Renewing all existing certificates..." | tee -a "$LOG_FILE"
    for domain_dir in "$LETSENCRYPT_DIR/live/"*; do
        if [[ -d "$domain_dir" ]]; then
            domain_name=$(basename "$domain_dir")
            echo "Renewing certificate for: $domain_name" | tee -a "$LOG_FILE"
            docker run --rm \
                -v "$LETSENCRYPT_DIR":/etc/letsencrypt \
                -v "$CHALLENGE_DIR":/var/www/certbot \
                certbot/certbot certonly \
                --webroot -w /var/www/certbot \
                -d "$domain_name" \
                -m "$EMAIL" \
                --agree-tos \
                --non-interactive \
                2>&1 | tee -a "$LOG_FILE"
        fi
    done
}

# Tworzenie nowych certyfikatów
create_certs() {
    echo "Creating new certificates for: $DOMAINS" | tee -a "$LOG_FILE"
    docker run --rm \
        -v "$LETSENCRYPT_DIR":/etc/letsencrypt \
        -v "$CHALLENGE_DIR":/var/www/certbot \
        certbot/certbot certonly \
        --webroot -w /var/www/certbot \
        -d "$DOMAINS" \
        -m "$EMAIL" \
        --agree-tos \
        --non-interactive \
        2>&1 | tee -a "$LOG_FILE"
}
delete_certs() {
    echo "Deleting certificates for: $DELETE_DOMAINS" | tee -a "$LOG_FILE"
    IFS=',' read -ra DOMAINS_ARR <<< "$DELETE_DOMAINS"
    for domain in "${DOMAINS_ARR[@]}"; do
        echo "Deleting certificate for: $domain" | tee -a "$LOG_FILE"

        # Usunięcie certyfikatu przez certbota
        docker run --rm \
            -v "$LETSENCRYPT_DIR":/etc/letsencrypt \
            certbot/certbot delete \
            --cert-name "$domain" \
            --non-interactive \
            --quiet \
            2>&1 | tee -a "$LOG_FILE"

        # Dodatkowe sprzątanie na wszelki wypadek (w kontenerze, jako root)
        docker run --rm \
            -v "$LETSENCRYPT_DIR":/etc/letsencrypt \
            alpine sh -c "rm -rf /etc/letsencrypt/live/$domain \
                             /etc/letsencrypt/archive/$domain \
                             /etc/letsencrypt/renewal/$domain.conf" \
            2>&1 | tee -a "$LOG_FILE"
    done
}

# Wykonanie akcji
if [ "$RENEW" = true ]; then
    renew_all_certs
elif [[ -n "$DELETE_DOMAINS" ]]; then
    delete_certs
else
    if [[ -z "$DOMAINS" ]]; then
        echo "Error: missing domains for new certificate creation." | tee -a "$LOG_FILE"
        usage
    fi
    create_certs
fi

echo "Certbot finished. Certificates are in $LETSENCRYPT_DIR" | tee -a "$LOG_FILE"

# Reload Nginx, jeśli kontener działa
if docker ps --format '{{.Names}}' | grep -q '^nginx$'; then
    echo "Reloading Nginx..." | tee -a "$LOG_FILE"
    docker exec nginx nginx -s reload | tee -a "$LOG_FILE"
    echo "Nginx reloaded." | tee -a "$LOG_FILE"
else
    echo "Nginx container not running, skipping reload." | tee -a "$LOG_FILE"
fi
