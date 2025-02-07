#!/bin/bash

ACTION=${1^^}

ACTION_UP=0
ACTION_DOWN=0

case "${ACTION}" in
  "UP") ACTION_UP=1;;
  "DOWN") ACTION_DOWN=1;;
  "RESTART") ACTION_UP=1;ACTION_DOWN=1;;
  *) echo "USAGE: $0 <up|down|restart>";exit
esac

APP_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; cd ../ ; pwd -P )

pushd ${APP_PATH}

if [[ ${ACTION_DOWN} -gt 0 ]]; then
  sudo docker-compose down --remove-orphans -v
fi
if [[ ${ACTION_UP} -gt 0 ]]; then
  sudo docker-compose up -V -d
fi

popd
