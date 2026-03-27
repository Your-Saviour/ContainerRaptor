# ContainerRaptor

Containerised [Velociraptor](https://docs.velociraptor.app/) server built on [Docker Hardened Images](https://docs.docker.com/dhi/) (DHI) for a minimal, near-zero CVE runtime.

## Prerequisites

- Docker with BuildKit
- DHI registry access: `docker login dhi.io`

## Quick Start

### Build from source

```bash
docker login dhi.io
docker compose up --build -d
```

### Pull from registry

```bash
docker pull <registry>/containerraptor:latest
docker run -d \
  --name containerraptor \
  -p 8889:8889 \
  -p 8000:8000 \
  -v velociraptor-config:/velociraptor/config \
  -v velociraptor-data:/velociraptor/data \
  -v velociraptor-logs:/velociraptor/logs \
  <registry>/containerraptor:latest
```

On first run the container will automatically generate a new server configuration with unique TLS certificates, create an admin user, and start the server.

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

## Configuration

To customise the server config, edit `server.config.yaml` in the `velociraptor-config` volume and restart the container.

## Building a Specific Version

| Build Arg | Default | Description |
|-----------|---------|-------------|
| `VELOCIRAPTOR_VERSION` | `0.76.1` | Velociraptor binary version |
| `VELOCIRAPTOR_RELEASE_TAG` | `v0.76` | GitHub release tag |

```bash
docker compose build --build-arg VELOCIRAPTOR_VERSION=0.76.1 --build-arg VELOCIRAPTOR_RELEASE_TAG=v0.76
```

## Reset

Wipe all data and regenerate config with fresh certificates:

```bash
docker compose down -v
docker compose up --build -d
```

## License

GPL-3.0 — see [LICENSE](LICENSE)
