# Nginx-docker

## Setup
* Set up the Environment variables in `.env` file, check `sample.env` file
* Create config files:
  * `${NGINX_CONF_DIR}/default_server.conf` - configuration of default server; you can copy `./templates/config/default_server.conf` file
  * `${NGINX_CONF_DIR}/nginx.conf` - nginx configuration; you can copy `./templates/config/nginx.conf` file
  * `${NGINX_CONF_DIR}/error-sites/404.html` - default html page for 404 (Not Found) error; you can copy `./templates/config/error-sites/404.hyml` file
  * `${NGINX_CONF_DIR}/error-sites/403.html` - default html page for 403 (Access Denied) error; you can copy `./templates/config/error-sites/403.hyml` file
  * `${NGINX_CONF_DIR}/sites/*.conf` - configuration files for enabled sites; you can use templates in `./templates/config/sites/*.conf.tmpl` files


## Default site
* Create default site in `${WWW_SRC_DIR}/default/index.html`; you can copy `./templates/src/default/index.html`

## Start Docker compose
```bash
docker compose up
```

## Others
* Reload Nginx: Execute the following command file within the `nginx` container:
  ```bash
  nginx -s reload
  ```
* create  Let’s Encrypt certificate:  Execute the following command, replacing YOUR@EMAIL.ARDRESS with your email address, MAIN_DOMAIN with your domain and SUBDOMAIN with each subdomain for which you want to create a certificate:
  ```bash
  ./bin/createCert.sh -d www.MAIN_DOMAIN,MAIN_DOMAIN,www.SUBDOMAIN.MAIN_DOMAIN,SUBDOMAIN.MAIN_DOMAIN -a YOUR@EMAIL.ARDRESS
  ```