#!/bin/sh
set -eu

CHECK_INTERVAL="${MT5_CHECK_INTERVAL:-5}"

echo "[Eden7] MT5 supervisor started"
echo "[Eden7] Check interval: ${CHECK_INTERVAL}s"

terminal_running() {
    pgrep -af 'terminal64.exe' >/dev/null 2>&1
}

start_terminal() {
    echo "[Eden7] Starting MetaTrader 5..."
    wine64 C:/MT5/terminal64.exe /portable /config:C:/MT5/common.ini &
    echo "[Eden7] terminal64.exe start requested"
}

while true; do
    if terminal_running; then
        sleep "$CHECK_INTERVAL"
        continue
    fi

    echo "[Eden7] terminal64.exe is not running"
    sleep 3

    if ! terminal_running; then
        start_terminal
    fi

    sleep "$CHECK_INTERVAL"
done
