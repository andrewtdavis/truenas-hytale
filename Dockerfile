FROM eclipse-temurin:25-jre

RUN apt-get update \
 && apt-get install -y --no-install-recommends curl unzip ca-certificates \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/hytale /data/state /data/config /data/universe /data/backups \
 && curl -fsSL -o /tmp/hytale-downloader.zip https://downloader.hytale.com/hytale-downloader.zip \
 && unzip /tmp/hytale-downloader.zip -d /opt/hytale \
 && chmod +x /opt/hytale/hytale-downloader \
 && rm -f /tmp/hytale-downloader.zip

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /data/state
ENTRYPOINT ["/entrypoint.sh"]
