FROM lprett/mt5linux:latest

USER root

COPY config.sh /app/src/config.sh
COPY automation.sh /app/src/automation.sh
COPY entrypoint.sh /opt/eden7-entrypoint.sh
COPY supervisor.sh /opt/eden7-supervisor.sh

RUN chmod +x /opt/eden7-entrypoint.sh /opt/eden7-supervisor.sh

ENTRYPOINT ["/opt/eden7-entrypoint.sh"]
