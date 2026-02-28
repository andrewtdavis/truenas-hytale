#!/usr/bin/env bash
set -euo pipefail

mkdir -p /data/state /data/config /data/universe /data/backups

cd /data/state

if [[ "${HYTALE_AUTO_UPDATE:-true}" == "true" ]]; then
  if [[ "${HYTALE_PATCHLINE:-release}" == "release" ]]; then
    /opt/hytale/hytale-downloader
  else
    /opt/hytale/hytale-downloader -patchline "${HYTALE_PATCHLINE}"
  fi
fi

cd /data/state/Server

for f in config.json permissions.json bans.json whitelist.json; do
  if [[ -f "$f" && ! -f "/data/config/$f" ]]; then
    mv "$f" "/data/config/$f"
  fi
  ln -sf "/data/config/$f" "$f"
done

if [[ -d universe && ! -L universe ]]; then
  cp -an universe/. /data/universe/ || true
  rm -rf universe
fi
ln -sfn /data/universe universe

exec java -XX:AOTCache=HytaleServer.aot ${JAVA_OPTS:-"-Xms4G -Xmx4G"} \
  -jar HytaleServer.jar \
  --assets ../Assets.zip \
  --bind "${HYTALE_BIND:-0.0.0.0:5520}" \
  ${HYTALE_EXTRA_ARGS:-}
