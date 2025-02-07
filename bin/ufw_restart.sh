#!/bin/bash

ufw reset
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow http
ufw allow https


NETWORK_HASH=$(sudo docker network ls | grep bridge | grep nginx-network | awk '{print $1;}')
echo "Network hash: ${NETWORK_HASH}"
if [[ -n "${NETWORK_HASH}" ]]; then
  NETWORK_INTERFACE=$(sudo ifconfig | grep "${NETWORK_HASH}" | awk '{print $1;}')
  NETWORK_INTERFACE=${NETWORK_INTERFACE::-1}
  echo "Network interface: ${NETWORK_INTERFACE}"
  if [[ -n "${NETWORK_INTERFACE}" ]]; then
    ufw allow in on ${NETWORK_INTERFACE}
  fi
fi

#ufw allow in on docker0
#ufw allow out on docker0
#ufw allow in on br-d5020c9aed29
#ufw allow out on br-d5020c9aed29
#ufw allow in on br-d7c9e2daebd8
#ufw allow out on br-d7c9e2daebd8
#ufw allow in on lo
#ufw allow out on lo

echo "y" | sudo ufw enable

#ufw allow ftp
#ufw allow ftp-data
#ufw allow sftp
#ufw allow ftps-data
#ufw allow ftps
#ufw allow smtp
#ufw allow mysql
#ufw allow from 85.128.218.63
#ufw allow from 85.128.142.46 to any port 3306
#ufw allow from 85.128.142.11 to any port 3306
#ufw allow 49152:65534/tcp
#ufw allow 49152:65534/udp
#ufw allow 36330

ufw status verbose
