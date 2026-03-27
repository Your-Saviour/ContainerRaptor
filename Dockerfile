# ============================================================
# ContainerRaptor - Velociraptor on Docker Hardened Images
# ============================================================

# ----- Stage 1: Builder -----
# Download the pre-built Velociraptor binary
FROM dhi.io/debian-base:bookworm-dev AS builder

USER root

ARG VELOCIRAPTOR_VERSION=0.76.1
ARG VELOCIRAPTOR_RELEASE_TAG=v0.76

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && curl -fsSL -o /tmp/velociraptor \
    "https://github.com/Velocidex/velociraptor/releases/download/${VELOCIRAPTOR_RELEASE_TAG}/velociraptor-v${VELOCIRAPTOR_VERSION}-linux-amd64" \
    && chmod +x /tmp/velociraptor \
    && /tmp/velociraptor version

# ----- Stage 2: Runtime -----
# Hardened Debian base with near-zero CVEs
FROM dhi.io/debian-base:bookworm

LABEL org.opencontainers.image.source=https://github.com/Your-Saviour/ContainerRaptor
LABEL org.opencontainers.image.description="Containerised Velociraptor server on Docker Hardened Images"
LABEL org.opencontainers.image.licenses=GPL-3.0

USER 0

# Install minimal runtime dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        util-linux \
        adduser \
    && rm -rf /var/lib/apt/lists/*

# Copy Velociraptor binary from builder
COPY --from=builder /tmp/velociraptor /usr/local/bin/velociraptor

# Copy entrypoint script
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create directories for volume mounts
RUN mkdir -p /velociraptor/config /velociraptor/data /velociraptor/logs

EXPOSE 8889 8000

ENTRYPOINT ["/entrypoint.sh"]
