#!/bin/sh
set -eu
[ -f .env ] || { echo "Crie .env com: cp .env.example .env"; exit 1; }
docker compose -f docker/docker-compose.yml up -d --build
