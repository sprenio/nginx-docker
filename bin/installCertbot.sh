#!/bin/bash

# remove certbot installed by apt
sudo apt-get remove certbot
# install certbot by snap
sudo snap install --classic certbot
# link certbot to /usr/bin/
sudo ln -s /snap/bin/certbot /usr/bin/certbot
