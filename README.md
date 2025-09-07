# Nginx-Docker

* [Overview](#-overview)
* [Setup](#-setup)
* [PHPMyAdmin](#-phpmyadmin)
* [Start Docker Compose](#-start-docker-compose)
* [TLS/SSL Certificates](#-tlsssl-certificates)
  * [Certbot](#1-certbot-http-01-validation)
    * [Create a new certificate](#create-a-new-certificate)
    * [Renew all existing certificates](#renew-all-existing-certificates)
    * [Automatic daily renewal (cron)](#automatic-daily-renewal-cron)
    * [Logs](#logs)
  * [acme.sh (DNS-01 validation)](#2-acmesh-dns-01-validation-via-helper-script)
    * [Installation and verification](#installation-and-verification)
    * [Example: Cloudflare](#example-cloudflare)
    * [Example: OVH](#example-ovh)
    * [Usage of `ssl_issue.sh`](#usage-of-ssl_issuesh)
    * [Automatic renewal](#automatic-renewal)
  * [Summary](#-summary)
* [Other commands](#-other-commands)


## 📖 Overview

This setup provides a **reverse proxy layer** on top of your other Docker containers. Its main responsibilities are:

- Listen on **ports 80 (HTTP) and 443 (HTTPS)**.
- Route requests to the correct backend container based on **domain/subdomain**.
- Terminate SSL/TLS (HTTPS) connections.
- Serve static files directly when appropriate.
- Protect backend containers from direct external access – backend services **do not need to expose ports** to the host.

### Architecture Diagram (ASCII)

                                        ┌──────────────────┐
                                        │  Internet / LAN  │
                                        └────────┬─────────┘
                                                 │
                                           Ports 80 & 443
                                                 │
    ┌─────────────────┐                 ┌────────↓────────┐
    │   PHPMyAdmin    ←─────────────────┤      Nginx      │  ← Reverse proxy container
    │                 │                 │  (main entry)   │
    └────────┬────────┘                 └────────┬────────┘
             │                                   │
             │   ┌─────────────┬─────────────┐   │
             │   │        Container 1        │   │
             ├───→    DB 1     │    APP 1    ←───│
             │   │             │             │   │
             │   └─────────────┴─────────────┘   │
             │                                   │
             │   ┌─────────────┬─────────────┐   │
             │   │        Container 2        │   │
             ├───→    DB 2     │    APP 2    ←───│
             │   │             │             │   │
             │   └─────────────┴─────────────┘   │
             │                                   │
             │   ┌─────────────┬─────────────┐   │
             │   │        Container 3        │   │
             └───→    DB 3     │    APP 3    ←───┘
                 │             │             │
                 └─────────────┴─────────────┘

- Each backend container only exposes **internal ports** (like `9000` for PHP-FPM).
- Nginx routes requests to the right container using **Docker network** (`reverse-proxy`) and `server_name`.
- Static files can be served directly from the Nginx container if volume-mounted.

---

## ⚙️ Setup

1. **Create Docker network**
   ```bash
   docker network create reverse-proxy
   ```  
2. **Environment variables**  
   Copy `.env` from `sample.env` and edit values as needed.
3. **Configuration files**
    * `${NGINX_CONF_DIR}/default_server.conf` — configuration of default server; you can copy `./templates/config/default_server.conf` file
    * `${NGINX_CONF_DIR}/nginx.conf` — nginx configuration; you can copy `./templates/config/nginx.conf` file
    * `${NGINX_CONF_DIR}/sites/*.conf` — configuration files for enabled sites; you can use templates in `./templates/config/sites/*.conf` files
    * `${PHPMYADMIN_CONF_DIR}/config.user.inc.php` — **PHPMyAdmin** — template config in `./templates/config/phpmyadmin/config.user.inc.php`
   > to copy all default configuration files, run `cp templates/config/*.conf config/` 
4. **Error pages**
    * `${NGINX_CONF_DIR}/error-sites/400.html` — default html page for 400 (Bad Request) error; you can copy `./templates/config/error-sites/400.html` file
    * `${NGINX_CONF_DIR}/error-sites/401.html` — default html page for 401 (Unauthorized) error; you can copy `./templates/config/error-sites/401.html` file
    * `${NGINX_CONF_DIR}/error-sites/403.html` — default html page for 403 (Forbidden) error; you can copy `./templates/config/error-sites/403.html` file
    * `${NGINX_CONF_DIR}/error-sites/404.html` — default html page for 404 (Not Found) error; you can copy `./templates/config/error-sites/404.html` file
    * `${NGINX_CONF_DIR}/error-sites/405.html` — default html page for 405 (Method Not Allowed) error; you can copy `./templates/config/error-sites/405.html` file
    * `${NGINX_CONF_DIR}/error-sites/500.html` — default html page for 500 (Internal Server Error) error; you can copy `./templates/config/error-sites/500.html` file
    * `${NGINX_CONF_DIR}/error-sites/502.html` — default html page for 502 (Bad Gateway) error; you can copy `./templates/config/error-sites/502.html` file
    * `${NGINX_CONF_DIR}/error-sites/503.html` — default html page for 503 (Service Unavailable) error; you can copy `./templates/config/error-sites/503.html` file
    * `${NGINX_CONF_DIR}/error-sites/504.html` — default html page for 504 (Gateway Timeout) error; you can copy `./templates/config/error-sites/504.html` file
    > to copy all default error pages, run `cp ./templates/config/error-sites/*.html ./config/error-sites/`
5. **Whitelist email fo oauth2**
   * `${OAUTH2_DIR}/authorized_emails.txt` - create this file and add your email address, you can use template in `./templates/oauth2/authorized_emails.txt` files
   > to create an empty allowlist file, run `touch ./oauth2/authorized_emails.txt` 
6. **Docker-compose configuration**
    * Create docker-compose.yaml file, you can copy `templates/docker-compose.yml`
   > to copy a default configuration file, run `cp ./templates/docker-compose.yml ./docker-compose.yml`
---

## 🗄️ PHPMyAdmin
* Accessible through Nginx reverse proxy (no ports exposed externally).
* Edit `${PHPMYADMIN_CONF_DIR}/config.user.inc.php` for custom servers, users, and auth type.
* To create an empty config file, run `touch ./config/phpmyadmin/config.user.inc.php`

---

## 🐳 Start Docker compose
```bash
docker compose up -V -d
```

## 🔒 TLS/SSL Certificates

This project supports two alternative methods of generating and renewing TLS/SSL certificates.  
Choose the one that best fits your setup.

### 1. Certbot (HTTP-01 validation)
See [Let's Encrypt documentation](https://letsencrypt.org/docs/) for more details.  
**Use when:**
- Your server is directly accessible on port `80` (no CDN/proxy in front, or you can temporarily disable it).
- You want a simple, script-based approach to generate certificates inside Docker.
#### Create a new certificate
Run the script with a comma-separated list of domains and an email address for notifications:
```bash
./bin/certbot_docker.sh -d www.MAIN_DOMAIN,MAIN_DOMAIN,www.SUBDOMAIN.MAIN_DOMAIN,SUBDOMAIN.MAIN_DOMAIN -e admin@example.com
````
#### Removing a certificate
To remove a certificate, run the script with the `-x` option and a comma-separated list of domains: 
```bash
./bin/certbot_docker.sh -x "www.MAIN_DOMAIN,www.OTHER_MAIN_DOMAIN" -e admin@example.com
```

#### Renew all existing certificates
Renew all existing certificates in the project:
```bash
./bin/certbot_docker.sh -e my@email.com -r
```
#### Automatic daily renewal (cron)
Add the following line to your crontab to automatically renew certificates and reload Nginx daily at 03:00:
```
0 3 * * * /path/to/project/bin/certbot_docker.sh -e my@email.com -r
```

#### Logs
Each run of the script generates a log file in `./logs/`, for example:
```bash
./logs/certbot_20250828_101500.log
```

### 2. acme.sh (DNS-01 validation via helper script)
Certificates are obtained via DNS challenges.  
**Use when:**
- Your domain is behind a CDN/proxy (e.g. Cloudflare orange cloud).
- You don't want to expose port 80 at all.
- You prefer fully automated issuance and renewal via DNS APIs.

#### Installation and verification
```bash
curl https://get.acme.sh | sh
export PATH="~/.acme.sh:$PATH"
acme.sh --version
```
#### Switch to **Let's Encrypt** as the default CA (recommended):
```bash
~/.acme.sh/acme.sh --set-default-ca --server letsencrypt
```
> ℹ️ By default, acme.sh uses ZeroSSL.  
> If you prefer ZeroSSL, register an account once with:
> ```bash
> ~/.acme.sh/acme.sh --register-account -m your@email.com
> ```
#### Account registration (required once)
Before issuing your first certificate, register an ACME account:
```bash
~/.acme.sh/acme.sh --register-account -m your@email.com
````
This step is required only once. After that, acme.sh will use the saved account credentials.

#### Example: Cloudflare
1. Create an API token in Cloudflare (scope: **DNS Edit** for the domain).
2. Run the helper script with your credentials for the first time:
   ```bash
   ./bin/ssl_issue.sh -p cf \
   --cf-token "your_cloudflare_api_token" \
   --cf-account-id "your_cloudflare_account_id" \
   -d www.example.com,example.com
   ```
   The script will pass your credentials to `acme.sh` and they will be stored automatically in:
   ```bash
   ~/.acme.sh/account.conf
   ```
   For future renewals, credentials will be read from `account.conf` - no need to provide them again.

#### Example: OVH
1. **Create API credentials** at [OVH API](https://www.ovh.com/auth/api/createToken) with DNS access:
   - GET /domain/zone/*
   - POST /domain/zone/*
   - DELETE /domain/zone/*
2. Run the helper script with your credentials for the first time:
   ```bash
   ./bin/ssl_issue.sh -p ovh \
   --ovh-ak "ApplicationKey" \
   --ovh-as "ApplicationSecret" \
   --ovh-ck "ConsumerKey" \
   -d www.example.com,example.com
   ```
   As with Cloudflare, credentials will be saved in:
   ```bash
   ~/.acme.sh/account.conf
   ```
   and reused automatically.

#### Usage of `ssl_issue.sh`
This script simplifies issuing and installing certificates via acme.sh:  
1. **Usage:**
   ```bash
   ./bin/ssl_issue.sh -p <plugin> -d <comma-separated list of domains> [-d <another list> ...] [--dry-run] [--cf-token ... --cf-account-id ...] [--ovh-ak ... --ovh-as ... --ovh-ck ...]
   ```
2. **Parameters:**
   * `-p <plugin>` - DNS plugin: cf (Cloudflare) or ovh.
   * `-d <domain1,domain2,...>` - comma-separated list of domains for a single certificate. You can provide multiple `-d` for multiple certificates.
   * `--cf-token`, `--cf-account-id` - Cloudflare credentials (only needed on first run).
   * `--ovh-ak`, `--ovh-as`, `--ovh-ck` - OVH credentials (only needed on first run).
   * `--dry-run` - optional, simulates actions without actually issuing or installing certificates.
3. **Example – multiple certificates**
   ```bash
   ./bin/ssl_issue.sh -p cf \
   -d www.mysite.com,mysite.com,www.admin.mysite.com \
   -d www.my_other_site.com,my_other_site.com
   ```
   Creates 2 certificates:
      - www.mysite.com.key / www.mysite.com.crt → covers www.mysite.com,mysite.com,www.admin.mysite.com
      - www.my_other_site.com.key / www.my_other_site.com.crt → covers www.my_other_site.com,my_other_site.com
4. **Dry-run example**
   ```bash
   ./bin/ssl_issue.sh -p ovh -d example.com,www.example.com --dry-run
   ```
   Shows all commands that would run, without executing them.

5. **Installation**
   * Certificates are installed in the SSL directory (`$SSL_CERTS_DIR` or default `./ssl/certs`).
   * Nginx is automatically reloaded after installation.
   * Existing certificates are backed up to {`SSL_DIRECTORY/backup_TIMESTAMP/` before overwriting.


#### Automatic renewal
- acme.sh automatically installs a cron job, if it is unable to create cron job, you will see an error message like `Failed to install cron job. You need to manually renew your certs.`.  
  In that case you can add a cron job by yourself:
  `/home/{user}/.acme.sh/acme.sh --cron --home "/home/{user}/.acme.sh" > /dev/null`
- Certificates are renewed before expiry and Nginx is reloaded.

### 👉 Summary:
- Use **Certbot** if you control port `80` and want a Docker-based setup.
- Use **acme.sh (DNS-01)** if your domain is proxied by a CDN (e.g. Cloudflare) or hosted at a provider with API support (e.g. OVH).


---
## 🔧 Other commands
* **Reload Nginx**
  ```bash
  docker exec nginx nginx -s reload
  ```
* **Stop Docker Compose**
  ```bash
  docker compose down --remove-orphans -v
  ```
* **Create Let's Encrypt certificate:**  
  Execute the following command, replacing YOUR@EMAIL.ARDRESS with your email address, MAIN_DOMAIN with your domain, and SUBDOMAIN with each subdomain for which you want to create a certificate:
  ```bash
  ./bin/createCerts.php -d www.MAIN_DOMAIN,MAIN_DOMAIN,www.SUBDOMAIN.MAIN_DOMAIN,SUBDOMAIN.MAIN_DOMAIN -a YOUR@EMAIL.ARDRESS
  ```
* **List of acme.sh certificates:**
    ```bash
    ~/.acme.sh/acme.sh --list
    ```
* **Remove acme.sh certificate:**
    ```bash
    ~/.acme.sh/acme.sh --remove -d example.com
    ```
---