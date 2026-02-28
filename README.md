# truenas-hytale

TrueNAS SCALE custom app base for running a Hytale server in Docker, with persistent bind mounts for server state, config, and world data.

## Files

- `Dockerfile`: Builds a Java 25-based Hytale server image.
- `entrypoint.sh`: Downloads/updates server files on start, then launches the server.
- `truenas-custom-app.yaml`: Base Compose-style YAML for TrueNAS custom app install.

## Prerequisites

- TrueNAS SCALE with Apps enabled.
- A container registry you can push to (GHCR, Docker Hub, etc.).
- Three datasets (or directories) on your pool:
  - `/mnt/POOL/hytale/state`
  - `/mnt/POOL/hytale/config`
  - `/mnt/POOL/hytale/universe`

Replace `POOL` with your actual pool name.

## Build and Push the Image

From this repo:

```bash
docker build -t ghcr.io/YOURORG/hytale-server:latest .
docker push ghcr.io/YOURORG/hytale-server:latest
```

Update `image:` in `truenas-custom-app.yaml` to your registry/repo path.

## TrueNAS Custom App Install

1. Open **Apps** -> **Discover Apps** -> **Custom App**.
2. Choose **Install via YAML**.
3. Paste `truenas-custom-app.yaml` content.
4. Update host bind-mount paths (`/mnt/POOL/...`) to your real dataset paths.
5. Install.

## Networking

- Exposed gameplay port: `5520/udp` (Hytale default).
- The YAML publishes `5520` on the TrueNAS host IP.

If your firewall is enabled, allow inbound UDP 5520 to the TrueNAS host.

## First Start and Authentication

On first run, complete account authentication from the server console:

1. Open container logs/shell in TrueNAS.
2. Run:

```bash
/auth login device
```

3. Follow the device-code URL and code prompts.

## Data Layout

Container paths:

- `/data/state`: downloaded server files and runtime data.
- `/data/config`: persisted JSON config files (`config.json`, `permissions.json`, etc.).
- `/data/universe`: persisted game world/universe data.

The entrypoint script symlinks config/universe into the server directory.

## Updates (Game Patches)

`HYTALE_AUTO_UPDATE=true` runs `hytale-downloader` at each container start, so restarting the app pulls latest server files for the selected patch line (`HYTALE_PATCHLINE`, default `release`).

Recommended update flow:

1. Stop server cleanly.
2. Restart/redeploy app.
3. Verify logs show updated version and successful startup.

Client and server versions must match.

## Run as UID/GID 568

The YAML uses:

```yaml
user: "568:568"
```

Ensure your dataset ACL/permissions allow UID/GID 568 read/write on all mounted paths.

## Source References

- TrueNAS custom app YAML docs:
  - https://www.truenas.com/docs/scale/25.10/scaleuireference/apps/installcustomappscreens/
- Hytale Server Manual:
  - https://support.hytale.com/hc/en-us/articles/45326769420827-Hytale-Server-Manual
