# Nginx-docker

## Setup
* Set up the Environment variables in `.env` file, check `sample.env` file
* Create config files:
  * `${NGINX_CONF_DIR}/default_server.conf` - configuration of default server; you can copy `./templates/config/default_server.conf` file
  * `${NGINX_CONF_DIR}/nginx.conf` - nginx configuration; you can copy `./templates/config/nginx.conf` file
  * `${NGINX_CONF_DIR}/error-sites/404.html` - default html page for 404 (Not Found) error; you can copy `./templates/config/error-site/404.hyml` file
  * `${NGINX_CONF_DIR}/error-sites/403.html` - default html page for 403 (Access Denied) error; you can copy `./templates/config/error-site/403.hyml` file
  * `${NGINX_CONF_DIR}/sites-enabled/*.conf` - configuration files for enabled sites; you can use templates in `./templates/config/sites/enabled/*.conf.tmpl` files


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
  