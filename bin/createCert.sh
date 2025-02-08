#!/bin/bash

if [[ $EUID -ne 0 ]]; then
  echo -e "Permission denied: This script requires root privileges.\nPlease run it with 'sudo' or as the root user." >&2
  exit 1
fi

APP_ROOT_DIR=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; cd ../ ; pwd -P )
ENV_FILE_PATH=${APP_ROOT_DIR}/.env

if [[ -f ${ENV_FILE_PATH} ]]; then
  export $(grep -v '^#' ${ENV_FILE_PATH} | xargs -d '\n' | tr -d "'")
else
 echo "env file ${ENV_FILE_PATH} doesn't exist, using default values:"
 CERT_CHALLENGE_DIR=${APP_ROOT_DIR}/cert_challenge
 SSL_CERTIFICATES_DIR=${APP_ROOT_DIR}/ssl_certificates
 echo "CERT_CHALLENGE_DIR: ${CERT_CHALLENGE_DIR}"
 echo "SSL_CERTIFICATES_DIR: ${SSL_CERTIFICATES_DIR}"
fi


DOMAINS="";
ACCOUNT="";

while getopts d:a: flag
do
    case "${flag}" in
        d) DOMAINS=${OPTARG};;
        a) ACCOUNT=${OPTARG};;
        *) echo "Invalid parameter ${flag}"
    esac
done

if [[ -z "${DOMAINS}" || -z "${ACCOUNT}" ]]; then
  echo "usage: $0 <OPTIONS>"
  echo "  options:"
  echo "    -d    coma separated list of domains"
  echo "    -a    email address for notifications"
  exit
fi

MAIN_DOMAIN=$(echo $DOMAINS | cut -d ',' -f 1);
echo "renew certbot for ${MAIN_DOMAIN}"
LIVE_DIR=/etc/letsencrypt/live/${MAIN_DOMAIN}
if [[ -f ${LIVE_DIR} ]]; then
  echo "${LIVE_DIR} already exist. Moving to ${LIVE_DIR}.bak"
  mv -f ${LIVE_DIR} ${LIVE_DIR}.bak
fi
/usr/bin/certbot certonly -n --agree-tos --webroot -w ${CERT_CHALLENGE_DIR} -d ${DOMAINS} -m ${ACCOUNT}

F=$(readlink -f /etc/letsencrypt/live/${MAIN_DOMAIN}/fullchain.pem)

P=$(readlink -f /etc/letsencrypt/live/${MAIN_DOMAIN}/privkey.pem)

SSL_DOMAIN_DIR="${SSL_CERTIFICATES_DIR}/${MAIN_DOMAIN}"
if [[ ! -d  "${SSL_DOMAIN_DIR}" ]];then
  mkdir -p "${SSL_DOMAIN_DIR}"
fi

cp $F ${SSL_DOMAIN_DIR}/fullchain.pem
cp $P ${SSL_DOMAIN_DIR}/privkey.pem