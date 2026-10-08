#!/bin/sh
set -eu

echo "[Eden7] Starting MT5 Linux environment"

# Preserve the upstream environment definitions when available.
if [ -f /app/src/env.sh ]; then
    . /app/src/env.sh
fi

export MT5_HOST="${MT5_HOST:-0.0.0.0}"
export RPYC_PORT="${RPYC_PORT:-18812}"
export NOVNC_PORT="${NOVNC_PORT:-8080}"
export WINEPREFIX="${WINEPREFIX:-/opt/wineprefix}"
export WIN_ROOT="${WIN_ROOT:-$WINEPREFIX/drive_c}"
export MT5="${MT5:-$WIN_ROOT/MT5}"

mkdir -p "$WINEPREFIX"
wineboot -init >/dev/null 2>&1 || true

echo "[Eden7] Starting upstream mt5linux services"
if [ ! -x /app/src/main.sh ]; then
    echo "[Eden7] ERROR: /app/src/main.sh not found"
    exit 1
fi

exec /app/src/main.sh
