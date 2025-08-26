# Nginx-Docker

* [Overview](#overview)
* [Setup](#setup)
* [PHPMyAdmin](#phpmyadmin)
* [Start Docker Compose](#start-docker-compose)
* [Other commands](#other-commands)


## Overview

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
             │   │        Container 1        │   │
             └───→    DB 3     │    APP 3    ←───┘
                 │             │             │
                 └─────────────┴─────────────┘

- Each backend container only exposes **internal ports** (like `9000` for PHP-FPM).
- Nginx routes requests to the right container using **Docker network** (`reverse-proxy`) and `server_name`.
- Static files can be served directly from the Nginx container if volume-mounted.

---

## Setup

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

---

## PHPMyAdmin
* Accessible through Nginx reverse proxy (no ports exposed externally).
* Edit `${PHPMYADMIN_CONF_DIR}/config.user.inc.php` for custom servers, users, and auth type.

---

## Start Docker compose
```bash
sudo docker-compose up -V -d
```

---
## Other commands
* **Reload Nginx**
  ```bash
  docker exec nginx nginx -s reload
  ```
 * **Stop Docker Compose**
  ```bash
  docker-compose down --remove-orphans -v
  ```
* **Create Let’s Encrypt certificate:**  
  Execute the following command, replacing YOUR@EMAIL.ARDRESS with your email address, MAIN_DOMAIN with your domain, and SUBDOMAIN with each subdomain for which you want to create a certificate:
  ```bash
  ./bin/createCerts.php -d www.MAIN_DOMAIN,MAIN_DOMAIN,www.SUBDOMAIN.MAIN_DOMAIN,SUBDOMAIN.MAIN_DOMAIN -a YOUR@EMAIL.ARDRESS
  ```
---