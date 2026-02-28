# truenas-hytale

TrueNAS SCALE custom app base for running a Hytale server in Docker, with persistent bind mounts for server state, config, and world data.

## Files

- `Dockerfile`: Builds a Java 25-based Hytale server image.
- `entrypoint.sh`: Downloads/updates server files on start, then launches the server.
- `truenas-custom-app.yaml`: Base Compose-style YAML for TrueNAS custom app install.
- `build-and-push.ps1`: Builds and pushes to GHCR using repo metadata from `.git`.

## Prerequisites

- TrueNAS SCALE with Apps enabled.
- A container registry you can push to (GHCR, Docker Hub, etc.).
- Four datasets (or directories) on your pool:
  - `/mnt/POOL/hytale/state`
  - `/mnt/POOL/hytale/config`
  - `/mnt/POOL/hytale/universe`
  - `/mnt/POOL/hytale/backups`

Replace `POOL` with your actual pool name.

Current public image:

- `ghcr.io/andrewtdavis/truenas-hytale:v0.1.1`

## Build and Push the Image (Podman Desktop + GHCR)

You can do this entirely from Podman Desktop after signing in to GitHub:

1. Open Podman Desktop -> **Images** -> **Build image**.
2. Set **Build context** to this repo folder (`truenas-hytale`).
3. Set **Dockerfile path** to `Dockerfile`.
4. Set image name to a lowercase GHCR path, for example:
   - `ghcr.io/YOUR_GITHUB_USERNAME/truenas-hytale:latest`
5. Build the image.
6. In **Images**, select the built image and click **Push**.
7. Push to `ghcr.io` (keep the same tag above).

If Podman Desktop already has your GitHub auth configured, it will use that for GHCR. If push prompts for credentials, use a GitHub PAT with `write:packages`.

Equivalent CLI commands from this repo:

```bash
podman build -t ghcr.io/YOUR_GITHUB_USERNAME/truenas-hytale:latest .
podman push ghcr.io/YOUR_GITHUB_USERNAME/truenas-hytale:latest
```

Recommended: also publish a version tag:

```bash
podman tag ghcr.io/YOUR_GITHUB_USERNAME/truenas-hytale:latest ghcr.io/YOUR_GITHUB_USERNAME/truenas-hytale:v0.1.0
podman push ghcr.io/YOUR_GITHUB_USERNAME/truenas-hytale:v0.1.0
```

Then update `image:` in `truenas-custom-app.yaml` to your registry/repo path.

## Automated Build/Push Script (Podman + Git Metadata)

Use `build-and-push.ps1` to auto-detect owner/repo from `git origin`, then run `podman build` and `podman push`.

From this repo (PowerShell):

```powershell
.\build-and-push.ps1
```

By default this publishes:

```text
ghcr.io/<github-owner>/<repo-name>:latest
```

Example for this repo with an explicit image name:

```powershell
.\build-and-push.ps1 -ImageName truenas-hytale -Tag latest -AlsoTagCommit
```

That example publishes:

- `ghcr.io/andrewtdavis/truenas-hytale:latest`
- `ghcr.io/andrewtdavis/truenas-hytale:git-<shortsha>`

Notes:

- The script requires an existing `podman login ghcr.io` session. If you already signed in via Podman Desktop, that is typically sufficient.
- CLI pushes and Podman Desktop use the same local engine/session, so pushed images are visible in Podman Desktop.

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

Your log line `Hytale Server Booted!` means the server started correctly.

If logs show `No server tokens configured. Use /auth login to authenticate.`, complete auth from the TrueNAS shell:

1. Follow logs:

```bash
docker logs -f hytale-server
```

2. Attach to the server console:

```bash
docker attach hytale-server
```

3. Run auth in the server console:

```bash
/auth login device
```

4. Follow the device-code URL and code prompts.
5. Detach from console without stopping server: press `Ctrl+P`, then `Ctrl+Q`.

If your container name differs, replace `hytale-server` in the commands above.

## Data Layout

Container paths:

- `/data/state`: downloaded server files and runtime data.
- `/data/config`: persisted JSON config files (`config.json`, `permissions.json`, etc.).
- `/data/universe`: persisted game world/universe data.
- `/data/backups`: persisted backup output from `--backup-dir /data/backups`.

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
