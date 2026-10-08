# Eden7 MT5 Linux

Docker environment for running MetaTrader 5 on Linux with Wine and remote desktop access. The container is based on the upstream [`lprett/mt5linux`](https://github.com/lprett/mt5linux) image, with Eden7 configuration and automation scripts.

## Architecture

Docker Compose builds the image from `docker/Dockerfile`. The entrypoint prepares the Wine environment and hands startup to the upstream `main.sh`. The MetaTrader/Wine prefix is persisted on the host at `data/wineprefix`, while noVNC provides browser access and mt5linux exposes the RPC interface for client applications such as Sentinel.

```text
Browser -> host:18080 -> container:8081 (noVNC HTTP)
                         container:5901 (WebSocket/VNC) -> desktop
Client  -> host:18812 -> container:18812 (mt5linux RPyC)
```

## Configure

Create a local environment file from the example:

```bash
cp .env.example .env
```

Set `MT5_LOGIN`, `MT5_PASSWORD`, `MT5_SERVER`, and `UI_PASSWORD` in `.env` as needed. Keep real credentials only in this local file; never commit it. `.env.example` contains empty credential fields and is safe to publish.

## Run

From the project root, start the service with Docker Compose:

```bash
docker compose -f docker/docker-compose.yml up -d --build
```

Open the noVNC interface at `http://localhost:18080` (or `http://<server-address>:18080` from another machine). The Wine prefix persists across container restarts in `data/wineprefix`; it can contain account settings and must not be committed or shared.

## Ports

| Host port | Container port | Purpose |
|---:|---:|---|
| 18080 | 8081 | noVNC HTTP interface |
| 5901 | 5901 | WebSocket/VNC desktop connection |
| 18812 | 18812 | mt5linux RPyC |

## Notes

This repository does not distribute MetaTrader 5 or broker credentials. MetaTrader 5 remains subject to its own licensing and your broker's terms. The persistent Wine prefix is runtime data, not source code.
