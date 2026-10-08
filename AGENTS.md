# AGENTS.md — Eden7Tech MT5 Linux

## Objetivo

Este arquivo orienta agentes de IA que trabalharem no repositório `eden7tech/mt5linux`.

O projeto executa o MetaTrader 5 em Linux/Docker usando Wine, com acesso visual via VNC/noVNC e futura integração com o Sentinel.

## Prioridade atual

1. Fazer o MT5 iniciar corretamente.
2. Fazer login automático usando `MT5_LOGIN`, `MT5_SERVER` e `MT5_PASSWORD`.
3. Preservar VNC/noVNC, que já está funcionando.
4. Evitar dois processos diferentes iniciando/controlando `terminal64.exe`.
5. Depois: supervisor, atualização automática e integração com Sentinel.

---

## Arquitetura

Estrutura:

```text
mt5linux/
├── data/
│   └── wineprefix/
├── docker/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── entrypoint.sh
│   └── supervisor.sh
├── scripts/
├── .env
├── .env.example
├── README.md
├── UPSTREAM.md
└── LICENSE
```

Imagem base:

```dockerfile
FROM lprett/mt5linux:latest
```

Scripts upstream ficam em:

```text
/app/src/
```

Principais:

```text
/app/src/main.sh
/app/src/env.sh
/app/src/config.sh
/app/src/mt5.sh
/app/src/vnc.sh
/app/src/automation.sh
```

MT5:

```text
/opt/wineprefix/drive_c/MT5/terminal64.exe
```

Configuração:

```text
/opt/wineprefix/drive_c/MT5/common.ini
```

---

## Credenciais

Nunca colocar credenciais no Git.

Usar `.env` local:

```text
MT5_HOST=0.0.0.0
MT5_LOGIN=...
MT5_PASSWORD=...
MT5_SERVER=...
RPYC_PORT=18812
NOVNC_PORT=5901
NOVNC_PAGE_PORT=8081
UI_PASSWORD=...
```

Nunca imprimir `MT5_PASSWORD`.

Para verificar somente se existe:

```sh
[ -n "$MT5_PASSWORD" ] && echo "PASSWORD_SET=SIM" || echo "PASSWORD_SET=NAO"
```

---

## VNC/noVNC — NÃO QUEBRAR

A configuração atual funcional é:

```text
NOVNC_PORT=5901
NOVNC_PAGE_PORT=8081
```

Mapeamentos:

```text
18080:8081
5901:5901
18812:18812
```

Fluxo:

```text
Browser
  |
  v
host:18080
  |
  v
container:8081 (noVNC HTTP)
  |
  v
container:5901 (WebSocket)
  |
  v
container:5900 (x11vnc)
  |
  v
Xvfb :0
```

Acesso:

```text
http://IP_DO_SERVIDOR:18080
```

O host utiliza a porta 8080 para Evolution API.

**Não usar 8080 para noVNC.**

---

## Configuração do MT5

O projeto possui um `config.sh` customizado copiado para:

```text
/app/src/config.sh
```

A função é:

```sh
apply_mt5_config()
```

O upstream originalmente usa:

```sh
test $FIRST_RUN || return
```

Como o `wineprefix` é persistente, a versão customizada deve permitir a aplicação da configuração quando `MT5_LOGIN` estiver definido:

```sh
apply_mt5_config() {
    [ -n "$MT5_LOGIN" ] || return
    ...
}
```

O resultado esperado em `common.ini` é:

```ini
[Common]
Login=...
Server=...
Password=...
```

O `common.ini` também contém as demais configurações do upstream.

---

## Estado conhecido do diagnóstico

Já foi confirmado que:

- `MT5_LOGIN` está disponível no container.
- `MT5_SERVER` está disponível.
- `MT5_PASSWORD` está disponível.
- `apply_mt5_config()` funciona quando executada manualmente.
- O `/app/src/main.sh` chama `apply_mt5_config` antes de `start_mt5`.

Trecho confirmado do `main.sh`:

```sh
init_wine

server_search_automation &
SERVER_SEARCH_PID=$!

update_manager_automation &
UPDATE_MANAGER_PID=$!

login_automation &
LOGIN_PID=$!

apply_mt5_config

start_mt5
```

Portanto, o problema investigado é o fluxo de inicialização.

---

## Problema arquitetural atual

O `entrypoint.sh` atual inicia:

```sh
/app/src/main.sh &
```

e depois inicia:

```text
/opt/eden7-supervisor.sh
```

O `supervisor.sh` também inicia diretamente:

```sh
wine64 C:/MT5/terminal64.exe /portable /config:C:/MT5/common.ini &
```

Assim existem dois mecanismos:

```text
entrypoint
   |
   +--> main.sh
   |      |
   |      +--> apply_mt5_config
   |      +--> start_mt5
   |
   +--> supervisor.sh
          |
          +--> terminal64.exe
```

Isso pode gerar condição de corrida.

### Direção preferida

Deixar o upstream `main.sh` ser o controlador principal:

```text
entrypoint.sh
   |
   v
/app/src/main.sh
   |
   +--> Xvfb
   +--> VNC
   +--> noVNC
   +--> init_wine
   +--> apply_mt5_config
   +--> start_mt5
   +--> RPyC
   +--> watchdog
```

Uma versão possível do `entrypoint.sh`:

```sh
#!/bin/sh
set -eu

echo "[Eden7] Starting MT5 Linux environment"

if [ -f /app/src/env.sh ]; then
    . /app/src/env.sh
fi

export MT5_HOST="${MT5_HOST:-0.0.0.0}"
export RPYC_PORT="${RPYC_PORT:-18812}"
export NOVNC_PORT="${NOVNC_PORT:-5901}"
export NOVNC_PAGE_PORT="${NOVNC_PAGE_PORT:-8081}"
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
```

Antes de aplicar, inspecionar o arquivo atual e verificar dependências.

O `supervisor.sh` não deve iniciar um segundo `terminal64.exe` enquanto o upstream já estiver controlando o processo.

---

## Docker Compose

Preservar a estrutura equivalente a:

```yaml
services:
  mt5linux:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: mt5linux
    restart: unless-stopped

    env_file:
      - ../.env

    environment:
      MT5_HOST: ${MT5_HOST:-0.0.0.0}
      RPYC_PORT: ${RPYC_PORT:-18812}
      NOVNC_PORT: ${NOVNC_PORT:-5901}
      NOVNC_PAGE_PORT: ${NOVNC_PAGE_PORT:-8081}
      UI_PASSWORD: ${UI_PASSWORD:-}

    ports:
      - "18080:8081"
      - "5901:5901"
      - "18812:18812"

    volumes:
      - ../data/wineprefix:/opt/wineprefix

    shm_size: "1gb"

    stop_grace_period: 30s
```

Não adicionar `MT5_LOGIN`, `MT5_PASSWORD` ou `MT5_SERVER` ao bloco `environment:`. Essas variáveis devem vir do `.env`.

---

## Dockerfile

Base:

```dockerfile
FROM lprett/mt5linux:latest
```

Os arquivos customizados necessários devem ser copiados, por exemplo:

```dockerfile
COPY entrypoint.sh /opt/entrypoint.sh
COPY supervisor.sh /opt/supervisor.sh
COPY config.sh /app/src/config.sh

RUN chmod +x     /opt/entrypoint.sh     /opt/supervisor.sh     /app/src/config.sh

ENTRYPOINT ["/opt/entrypoint.sh"]
```

Não remover o `config.sh` customizado sem verificar o impacto.

---

## Wineprefix

O prefix persistente é:

```text
data/wineprefix
```

montado em:

```text
/opt/wineprefix
```

Não apagar nem recriar automaticamente.

Nunca executar sem autorização:

```sh
rm -rf data/wineprefix
```

ou ações equivalentes destrutivas.

---

## Diagnóstico

### Container

```bash
docker ps --filter name=mt5linux
```

### Logs

```bash
docker logs mt5linux
```

### Ambiente sem expor senha

```bash
docker exec mt5linux sh -c '
echo "LOGIN=$MT5_LOGIN"
echo "SERVER=$MT5_SERVER"
echo "PASSWORD_SET=$([ -n "$MT5_PASSWORD" ] && echo SIM || echo NAO)"
'
```

### Configuração

```bash
docker exec mt5linux sh -c '
grep -E "^Login=|^Server=" /opt/wineprefix/drive_c/MT5/common.ini
'
```

Não mostrar `Password=`.

### Processo MT5

```bash
docker exec mt5linux pgrep -af terminal64.exe
```

### Processos Wine

```bash
docker exec mt5linux pgrep -af wine
```

### Ver main.sh

```bash
docker exec mt5linux sh -c 'sed -n "1,55p" /app/src/main.sh'
```

### Confirmar chamadas

```bash
docker exec mt5linux sh -c '
grep -n "apply_mt5_config\|start_mt5\|init_wine" /app/src/main.sh
'
```

### Testar configuração manualmente

```bash
docker exec mt5linux sh -c '
. /app/src/env.sh
. /app/src/config.sh
apply_mt5_config
echo "RET=$?"
grep -E "^Login=|^Server=" /opt/wineprefix/drive_c/MT5/common.ini
'
```

---

## Regras para o agente

### Sempre

- Ler este arquivo antes de modificar.
- Inspecionar o estado atual antes de editar.
- Fazer mudanças pequenas.
- Preservar VNC/noVNC.
- Preservar o wineprefix.
- Nunca expor senha.
- Nunca commitar `.env`.
- Validar sintaxe dos scripts alterados.
- Após mudanças no Dockerfile/Compose, executar `docker compose config` quando possível.
- Usar logs para confirmar comportamento.
- Verificar o upstream antes de substituir componentes.
- Informar quais arquivos foram alterados.

### Nunca

- Apagar `data/wineprefix` sem autorização.
- Trocar portas do noVNC sem necessidade.
- Usar 8080 para noVNC.
- Colocar credenciais em documentação.
- Fazer commit do `.env`.
- Criar segundo `terminal64.exe` sem entender o fluxo.
- Reescrever o projeto inteiro para resolver um problema específico.
- Fazer grandes refatorações durante diagnóstico.

---

## Próximo objetivo

Resolver:

> MT5 inicia, mas não está entrando automaticamente na conta configurada.

O teste manual de:

```sh
. /app/src/env.sh
. /app/src/config.sh
apply_mt5_config
```

já demonstrou que a configuração funciona.

O fluxo desejado é:

```text
MT5_LOGIN
MT5_SERVER
MT5_PASSWORD
       |
       v
apply_mt5_config
       |
       v
common.ini
       |
       v
terminal64.exe
```

O VNC/noVNC já funciona e não deve ser alterado durante essa correção.

---

## Sentinel

`mt5linux` e `Sentinel` são projetos separados.

Arquitetura futura:

```text
MT5 Linux
   |
   +--> MT5 terminal
   +--> histórico de mercado
   +--> RPyC/API
   |
   v
Sentinel
   |
   +--> análise
   +--> modelos
   +--> estratégias
```

Não misturar os repositórios sem necessidade.

---

## Princípio de trabalho

Desenvolvimento incremental:

1. Reproduzir.
2. Identificar a causa.
3. Fazer a menor alteração possível.
4. Validar.
5. Registrar o comportamento.
6. Só então avançar.

Não transformar um problema específico em uma reescrita completa.
