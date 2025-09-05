#!/bin/bash

set -e
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SSL_DIR="$(realpath "${SCRIPT_DIR}/../ssl")"
ACCOUNT_CONF="$HOME/.acme.sh/account.conf"

usage() {
    echo "Usage: $0 -p <plugin_name> [-d <comma-separated list of domains>]... [--dry-run] [--cf-token <token> --cf-account-id <id>] [--ovh-ak <key> --ovh-as <secret> --ovh-ck <ck>]"
    echo "  -p plugin_name: 'ovh' or 'cf'"
    echo "  -d domains: comma-separated list of domains (example: example.com,www.example.com)"
    echo "  --dry-run: simulate the actions without executing them"
    echo "  --cf-token: Cloudflare API token"
    echo "  --cf-account-id: Cloudflare account ID"
    echo "  --ovh-ak: OVH Application Key"
    echo "  --ovh-as: OVH Application Secret"
    echo "  --ovh-ck: OVH Consumer Key"
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

CF_TOKEN=""
CF_ACCOUNT_ID=""
OVH_AK=""
OVH_AS=""
OVH_CK=""

# Parsowanie parametrów
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -p)
            PLUGIN="$2"; shift 2;;
        -d)
            [[ -z "$2" ]] && error_exit "-d requires a comma-separated list of domains"
            DOMAIN_LISTS+=("$2"); shift 2;;
        --dry-run)
            DRY_RUN=1; shift;;
        --cf-token)
            CF_TOKEN="$2"; shift 2;;
        --cf-account-id)
            CF_ACCOUNT_ID="$2"; shift 2;;
        --ovh-ak)
            OVH_AK="$2"; shift 2;;
        --ovh-as)
            OVH_AS="$2"; shift 2;;
        --ovh-ck)
            OVH_CK="$2"; shift 2;;
        *)
          echo "Unknown option: $1"
            usage;;
    esac
done

# Walidacja parametrów
[[ -z "$PLUGIN" || ${#DOMAIN_LISTS[@]} -eq 0 ]] && usage
[[ "$PLUGIN" != "ovh" && "$PLUGIN" != "cf" ]] && error_exit "Plugin must be 'ovh' or 'cf'"

# Zapisanie danych uwierzytelniających do account.conf (jeśli podano)
mkdir -p "$(dirname "$ACCOUNT_CONF")"
touch "$ACCOUNT_CONF"
chmod 600 "$ACCOUNT_CONF"

if [[ "$PLUGIN" == "cf" && -n "$CF_TOKEN" && -n "$CF_ACCOUNT_ID" ]]; then
    log "Saving Cloudflare credentials to $ACCOUNT_CONF"
    sed -i '/^CF_Token=/d;/^CF_Account_ID=/d' "$ACCOUNT_CONF"
    {
      echo "CF_Token='$CF_TOKEN'"
      echo "CF_Account_ID='$CF_ACCOUNT_ID'"
    } >> "$ACCOUNT_CONF"
fi

if [[ "$PLUGIN" == "ovh" && -n "$OVH_AK" && -n "$OVH_AS" && -n "$OVH_CK" ]]; then
    log "Saving OVH credentials to $ACCOUNT_CONF"
    sed -i '/^OVH_AK=/d;/^OVH_AS=/d;/^OVH_CK=/d' "$ACCOUNT_CONF"
    {
      echo "OVH_AK='$OVH_AK'"
      echo "OVH_AS='$OVH_AS'"
      echo "OVH_CK='$OVH_CK'"
    } >> "$ACCOUNT_CONF"
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

    if [[ $DRY_RUN -eq 0 ]]; then
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
    fi

    # Issue certyfikatu
    ISSUE_CMD="${ACME_SH_PATH} --issue --force --dns dns_${PLUGIN}"
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
--fullchain-file ${SSL_DIR}/${PRIMARY_DOMAIN}.crt"

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
log "Reload nginx configuration."
RELOAD_CMD="docker exec nginx nginx -s reload"
if [[ $DRY_RUN -eq 1 ]]; then
  log "[DRY RUN] Would run: ${RELOAD_CMD}"
else
  if ! eval "$RELOAD_CMD"; then
      error_exit "Failed to reload nginx configuration"
  fi
fi
