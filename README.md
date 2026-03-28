# ContainerRaptor

Containerised [Velociraptor](https://docs.velociraptor.app/) server built on [Docker Hardened Images](https://docs.docker.com/dhi/) (DHI) for a minimal, near-zero CVE runtime.

## Prerequisites

- Docker with BuildKit
- DHI registry access: `docker login dhi.io`

## Quick Start

### Build from source

```bash
docker login dhi.io
VR_SERVER_DNS=vr.example.com docker compose up --build -d
```

### Pull from registry

```bash
docker pull <registry>/containerraptor:latest
docker run -d \
  --name containerraptor \
  -e VR_SERVER_DNS=vr.example.com \
  -p 8889:8889 \
  -p 8000:8000 \
  -v velociraptor-config:/velociraptor/config \
  -v velociraptor-data:/velociraptor/data \
  -v velociraptor-logs:/velociraptor/logs \
  <registry>/containerraptor:latest
```

On first run the container will automatically generate a new server configuration with unique TLS certificates, create an admin user, and start the server.

> **Note:** `VR_SERVER_DNS` is required on first run. Velociraptor clients need a DNS name to locate the server — the generated config embeds this into `Client.server_urls` so that client packages connect to `https://<VR_SERVER_DNS>:8000/`. On subsequent runs the existing config is reused and the variable is not needed.

Access the GUI at **https://localhost:8889** (self-signed certificate).

Default credentials: `admin` / `admin` — **change the password after first login.**

## Ports

| Port | Purpose |
|------|---------|
| 8889 | Web GUI (HTTPS) |
| 8000 | Client frontend (HTTPS) |

## Volumes

| Volume | Path | Contents |
|--------|------|----------|
| `velociraptor-config` | `/velociraptor/config` | Server config and TLS certificates |
| `velociraptor-data` | `/velociraptor/data` | Datastore (clients, artifacts) |
| `velociraptor-logs` | `/velociraptor/logs` | Application logs |

## Generating Client Packages

Client installers with your server's configuration embedded can be generated directly from the GUI using [server artifacts](https://docs.velociraptor.app/docs/deployment/clients/):

1. Navigate to **Server Artifacts** in the sidebar
2. Search for the artifact matching your target platform:
   - **`Server.Utils.CreateMSI`** — Windows MSI installer
   - **`Server.Utils.CreateLinuxPackages`** — Linux DEB/RPM packages
3. Click **Launch**
4. Download the completed installers from the **Uploaded Files** tab

The server automatically downloads the correct Velociraptor binaries from GitHub and repacks them with your organisation's client configuration and TLS certificates.

## Configuration

### Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `VR_SERVER_DNS` | Yes (first run) | DNS name clients use to reach the server (e.g. `vr.example.com`) |

To customise the server config, edit `server.config.yaml` in the `velociraptor-config` volume and restart the container.

### Build Args

| Build Arg | Default | Description |
|-----------|---------|-------------|
| `VELOCIRAPTOR_VERSION` | `0.76.1` | Velociraptor binary version |
| `VELOCIRAPTOR_RELEASE_TAG` | `v0.76` | GitHub release tag |

```bash
docker compose build --build-arg VELOCIRAPTOR_VERSION=0.76.1 --build-arg VELOCIRAPTOR_RELEASE_TAG=v0.76
```

## Reset

Wipe all data and regenerate config with fresh certificates and a new DNS name:

```bash
docker compose down -v
VR_SERVER_DNS=vr.example.com docker compose up --build -d
```

## License

GPL-3.0 — see [LICENSE](LICENSE)
