#!/bin/sh
set -eu
docker ps --filter name=mt5linux
echo
docker exec mt5linux sh -c 'pgrep -af terminal64.exe || true'
echo
docker logs --tail 30 mt5linux | grep -E '18812|RPyC|supervisor|terminal64' || true
