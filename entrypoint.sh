#!/usr/bin/env bash
set -euo pipefail

mkdir -p /data/state /data/config /data/universe /data/backups

cd /data/state

find_latest_zip() {
  find /data/state -maxdepth 1 -type f -name '*.zip' -printf '%T@ %p\n' | sort -nr | head -n1 | awk '{print $2}'
}

extract_version_from_zip_path() {
  local zip_path="$1"
  local name
  name="$(basename "$zip_path")"
  echo "${name%.zip}"
}

extract_hash_from_version() {
  local version="$1"
  if [[ "$version" =~ -([0-9a-fA-F]+)$ ]]; then
    echo "${BASH_REMATCH[1],,}"
  fi
}

get_latest_remote_version() {
  local patchline="$1"
  local url="${HYTALE_VERSION_CHECK_URL:-https://hytaleversions.io/}"
  local html section

  html="$(curl -fsSL "$url")" || return 1

  if [[ "$patchline" == "release" ]]; then
    section="$(awk '/### Stable Releases/{flag=1; next} /### Pre-Releases/{flag=0} flag {print}' <<< "$html")"
  else
    section="$(awk '/### Pre-Releases/{flag=1; next} /## Frequently Asked Questions/{flag=0} flag {print}' <<< "$html")"
  fi

  grep -Eo '[0-9]{4}\.[0-9]{2}\.[0-9]{2}-[0-9a-f]+' <<< "$section" | head -n1
}

download_server() {
  if [[ "${HYTALE_PATCHLINE:-release}" == "release" ]]; then
    /opt/hytale/hytale-downloader
  else
    /opt/hytale/hytale-downloader -patchline "${HYTALE_PATCHLINE}"
  fi
}

if [[ "${HYTALE_AUTO_UPDATE:-true}" == "true" ]]; then
  latest_zip="$(find_latest_zip || true)"
  local_version=""
  local_hash=""
  remote_version=""
  remote_hash=""

  if [[ -n "${latest_zip:-}" ]]; then
    local_version="$(extract_version_from_zip_path "$latest_zip")"
    local_hash="$(extract_hash_from_version "$local_version" || true)"
  fi

  normalized_patchline="${HYTALE_PATCHLINE:-release}"
  normalized_patchline="${normalized_patchline,,}"
  if [[ "$normalized_patchline" == *"pre"* ]]; then
    normalized_patchline="pre-release"
  else
    normalized_patchline="release"
  fi

  if [[ "${HYTALE_CHECK_REMOTE_VERSION:-true}" == "true" ]]; then
    remote_version="$(get_latest_remote_version "$normalized_patchline" || true)"
    remote_hash="$(extract_hash_from_version "$remote_version" || true)"
  fi

  if [[ -n "${local_hash:-}" && -n "${remote_hash:-}" && "$local_hash" == "$remote_hash" ]]; then
    echo "Local archive hash matches latest $normalized_patchline hash ($remote_hash), skipping download."
  elif [[ "${HYTALE_CHECK_REMOTE_VERSION:-true}" == "true" && -z "${remote_hash:-}" ]]; then
    echo "Could not read remote version; downloading server files as fail-safe."
    download_server
  elif [[ "${HYTALE_CHECK_REMOTE_VERSION:-true}" != "true" && "${HYTALE_SKIP_DOWNLOAD_IF_PRESENT:-true}" == "true" && -n "${latest_zip:-}" ]]; then
    echo "Remote version check disabled and existing archive found, skipping download: $latest_zip"
  else
    echo "Local archive hash differs from latest $normalized_patchline hash, downloading updates."
    download_server
  fi
fi

if [[ ! -d /data/state/Server || ! -f /data/state/Assets.zip ]]; then
  latest_zip="$(find_latest_zip || true)"
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

world_file_arg=()
if [[ -n "${HYTALE_WORLD_FILE:-}" ]]; then
  world_path="${HYTALE_WORLD_FILE}"
  if [[ "$world_path" != /* ]]; then
    world_path="/$world_path"
  fi
  world_file_arg=("${HYTALE_WORLD_FLAG:---world}" "$world_path")
fi

# Intentionally split option strings into arguments.
# shellcheck disable=SC2206
java_opts=( ${JAVA_OPTS:-"-Xms4G -Xmx4G"} )

cmd=(
  java
  -XX:AOTCache=HytaleServer.aot
  "${java_opts[@]}"
  -jar HytaleServer.jar
  --assets ../Assets.zip
  --bind "${HYTALE_BIND:-0.0.0.0:5520}"
)

if [[ ${#world_file_arg[@]} -gt 0 ]]; then
  cmd+=("${world_file_arg[@]}")
fi

if [[ -n "${HYTALE_WORLD_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  world_args=( ${HYTALE_WORLD_ARGS} )
  cmd+=("${world_args[@]}")
fi

if [[ -n "${HYTALE_EXTRA_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  extra_args=( ${HYTALE_EXTRA_ARGS} )
  cmd+=("${extra_args[@]}")
fi

exec "${cmd[@]}"
