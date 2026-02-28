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

if [[ ! -d /data/state/Server || ! -f /data/state/Assets.zip ]]; then
  latest_zip="$(find /data/state -maxdepth 1 -type f -name '*.zip' -printf '%T@ %p\n' | sort -nr | head -n1 | awk '{print $2}')"
  if [[ -z "${latest_zip:-}" ]]; then
    echo "No game zip found in /data/state and required files are missing (Server/, Assets.zip)." >&2
    exit 1
  fi

  tmp_extract="/tmp/hytale-extract"
  rm -rf "$tmp_extract"
  mkdir -p "$tmp_extract"

  unzip -o "$latest_zip" -d "$tmp_extract" >/dev/null

  if [[ -d "$tmp_extract/Server" && -f "$tmp_extract/Assets.zip" ]]; then
    if [[ ! -d /data/state/Server ]]; then
      cp -a "$tmp_extract/Server" /data/state/Server
    fi
    cp -a "$tmp_extract/Assets.zip" /data/state/Assets.zip
  else
    server_jar="$(find "$tmp_extract" -type f -name 'HytaleServer.jar' | head -n1 || true)"
    assets_zip="$(find "$tmp_extract" -type f -name 'Assets.zip' | head -n1 || true)"

    if [[ -z "$server_jar" || -z "$assets_zip" ]]; then
      echo "Could not locate Server/HytaleServer.jar and Assets.zip after extracting $latest_zip" >&2
      exit 1
    fi

    server_dir="$(dirname "$server_jar")"
    if [[ ! -d /data/state/Server ]]; then
      cp -a "$server_dir" /data/state/Server
    fi
    cp -a "$assets_zip" /data/state/Assets.zip
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
