#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SSL_DIR="$(realpath "${SCRIPT_DIR}/../ssl")"

usage() {
    echo "Usage: $0 -p <plugin_name> [-d <comma-separated list of domains>]... [--dry-run]"
    echo "  -p plugin_name: 'ovh' or 'cf'"
    echo "  -d domains: comma-separated list of domains (example: example.com,www.example.com)"
    echo "  --dry-run: simulate the actions without executing them"
    exit 1
}

log() {
    echo "[INFO] $1"
}

error_exit() {
    echo "[ERROR] $1" >&2
    exit 1
}

DRY_RUN=0
PLUGIN=""
DOMAIN_LISTS=()

# Parsowanie parametrów
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -p)
            PLUGIN="$2"
            shift 2
            ;;
        -d)
            if [[ -z "$2" ]]; then
                error_exit "-d requires a comma-separated list of domains"
            fi
            DOMAIN_LISTS+=("$2")
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        *)
            usage
            ;;
    esac
done

# Walidacja parametrów
if [[ -z "$PLUGIN" || ${#DOMAIN_LISTS[@]} -eq 0 ]]; then
    usage
fi

if [[ "$PLUGIN" != "ovh" && "$PLUGIN" != "cf" ]]; then
    error_exit "Plugin must be 'ovh' or 'cf'"
fi

ACME_ENV="$HOME/.acme.sh/acme.sh.env"
if [[ -f "$ACME_ENV" ]]; then
    log "Loading acme.sh environment from $ACME_ENV"
    # Źródłowanie pliku, aby zmienne OVH/CF były dostępne
    # shellcheck source=/dev/null
    source "$ACME_ENV"
else
    log "[WARNING] acme.sh environment file not found at $ACME_ENV"
fi

# Katalog SSL
SSL_DIR="${SSL_CERTS_DIR:-$DEFAULT_SSL_DIR}"
BACKUP_DIR="${SSL_DIR}/backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

log "Using SSL directory: $SSL_DIR"
log "Backup directory: $BACKUP_DIR"

ACME_SH_PATH="$HOME/.acme.sh/acme.sh"
if [[ -z "$ACME_SH_PATH" ]]; then
    error_exit "acme.sh not found in PATH. Please install it or add to PATH."
fi
log "Using acme.sh: $ACME_SH_PATH"

# Przetwarzanie każdej listy domen
for DOMAIN_CSV in "${DOMAIN_LISTS[@]}"; do
    IFS=',' read -r -a DOMAINS <<< "$DOMAIN_CSV"
    PRIMARY_DOMAIN="${DOMAINS[0]}"

    log "Processing certificate for domains: ${DOMAINS[*]}"

    # Backup istniejących certyfikatów
    for domain in "${DOMAINS[@]}"; do
        KEY_FILE="${SSL_DIR}/${domain}.key"
        CRT_FILE="${SSL_DIR}/${domain}.crt"
        if [[ -f "$KEY_FILE" || -f "$CRT_FILE" ]]; then
            log "Backing up existing cert/key for $domain"
            mkdir -p "${BACKUP_DIR}/$domain"
            [[ -f "$KEY_FILE" ]] && cp "$KEY_FILE" "${BACKUP_DIR}/$domain/"
            [[ -f "$CRT_FILE" ]] && cp "$CRT_FILE" "${BACKUP_DIR}/$domain/"
        fi
    done

    # Issue certyfikatu
    ISSUE_CMD="${ACME_SH_PATH} --issue --dns dns_${PLUGIN}"
    for domain in "${DOMAINS[@]}"; do
        ISSUE_CMD+=" -d $domain"
    done

    if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY RUN] Would run: $ISSUE_CMD"
    else
        log "Running: $ISSUE_CMD"
        if ! eval "$ISSUE_CMD"; then
            error_exit "Failed to issue certificate for ${DOMAINS[*]}"
        fi
    fi

    # Instalacja certyfikatu dla pierwszej domeny
    INSTALL_CMD="${ACME_SH_PATH} --install-cert -d ${PRIMARY_DOMAIN} \
--key-file ${SSL_DIR}/${PRIMARY_DOMAIN}.key \
--fullchain-file ${SSL_DIR}/${PRIMARY_DOMAIN}.crt \
--reloadcmd \"docker exec nginx nginx -s reload\""

    if [[ $DRY_RUN -eq 1 ]]; then
        log "[DRY RUN] Would run: $INSTALL_CMD"
    else
        log "Installing certificate for primary domain: $PRIMARY_DOMAIN"
        if ! eval "$INSTALL_CMD"; then
            error_exit "Failed to install certificate for ${PRIMARY_DOMAIN}"
        fi
    fi

    log "Certificate processed for ${PRIMARY_DOMAIN}"
done

log "All certificates processed successfully."
