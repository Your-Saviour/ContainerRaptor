# ContainerRaptor

Containerised Velociraptor server built on Docker Hardened Images (DHI).

## Project Structure

```
ContainerRaptor/
├── Dockerfile              # Multi-stage: dhi.io/debian-base builder + runtime
├── docker-compose.yml      # Single service, named volumes, bridge network
├── scripts/
│   └── entrypoint.sh       # First-run init + server startup
├── .gitignore
├── README.md
└── LICENSE                 # GPL-3.0
```

## How It Works

### Multi-stage Dockerfile

| Stage | Image | Purpose |
|-------|-------|---------|
| Builder | `dhi.io/debian-base:bookworm-dev` | Downloads Velociraptor binary from GitHub releases |
| Runtime | `dhi.io/debian-base:bookworm` | Runs Velociraptor as the `velociraptor` user |

No configuration or certificates are baked into the image. Each container generates its own unique server config and TLS certificates on first startup.

### Entrypoint Lifecycle

A single script (`scripts/entrypoint.sh`) handles everything:

- **First run** (no `server.config.yaml`): creates the velociraptor system user, generates config via `velociraptor config generate`, patches bind addresses (`127.0.0.1` → `0.0.0.0`) and datastore paths (`/var/tmp/velociraptor` → `/velociraptor/data`), creates admin user, sets permissions, starts the server
- **Subsequent runs**: ensures the velociraptor user exists, fixes volume permissions, starts the server

The entrypoint runs as root for user creation and permissions, then `exec runuser -u velociraptor` for the server process.

## Key Architecture Decisions

- **DHI base images**: `dhi.io/debian-base:bookworm` (runtime) and `bookworm-dev` (builder). Non-root by default — need `USER 0` for package installs.
- **Velociraptor must run as the `velociraptor` system user** — it will not work under other users.
- **Bind addresses patched via sed**: Default config binds to `127.0.0.1`; entrypoint patches to `0.0.0.0` for container networking.
- **Velociraptor release URLs**: The release tag differs from the version (e.g., tag `v0.76` contains binary `v0.76.1`). Both `VELOCIRAPTOR_VERSION` and `VELOCIRAPTOR_RELEASE_TAG` are separate build args in the Dockerfile.
- **Admin user creation**: `velociraptor user add admin admin --role administrator` — username and password are positional args.

## Build & Test

```bash
docker login dhi.io                    # Required for DHI images
docker compose up --build -d           # Build and start
docker logs containerraptor            # Check logs
docker compose down -v                 # Full reset (removes config + data)
```

## Conventions

- Shell scripts use `set -e` and explicit error handling
- Idempotent user creation (checks `getent` before `adduser`/`addgroup`)
- Config existence (`server.config.yaml`) is the only state check — no marker files
