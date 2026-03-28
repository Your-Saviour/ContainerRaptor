# ============================================================
# ContainerRaptor - Velociraptor on Docker Hardened Images
# ============================================================

# ----- Stage 1: Builder -----
# Build Velociraptor from source
FROM golang:1.25-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
        nodejs npm ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY TraumaRaptor/ /build/velociraptor
WORKDIR /build/velociraptor

RUN go run make.go -v assets
RUN go run make.go -v linux

RUN chmod +x output/velociraptor-*-linux-amd64 \
    && cp output/velociraptor-*-linux-amd64 /tmp/velociraptor \
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
COPY ContainerRaptor/scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create directories for volume mounts
RUN mkdir -p /velociraptor/config /velociraptor/data /velociraptor/logs

EXPOSE 8889 8000

ENTRYPOINT ["/entrypoint.sh"]
