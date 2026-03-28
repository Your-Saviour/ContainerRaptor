#!/bin/bash
set -e

CONFIG_DIR="/velociraptor/config"
DATA_DIR="/velociraptor/data"
LOGS_DIR="/velociraptor/logs"
CONFIG_FILE="${CONFIG_DIR}/server.config.yaml"
VELOCIRAPTOR_BIN="/usr/local/bin/velociraptor"

# First-run initialization
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "=== First run detected - initializing ContainerRaptor ==="

    # Require DNS name for client connectivity
    if [ -z "${VR_SERVER_DNS}" ]; then
        echo "ERROR: VR_SERVER_DNS must be set (e.g. vr.example.com)"
        echo "Clients need a DNS name to reach the server."
        exit 1
    fi

    # Create velociraptor system user and group
    if ! getent group velociraptor > /dev/null 2>&1; then
        addgroup --system velociraptor
    fi
    if ! getent passwd velociraptor > /dev/null 2>&1; then
        adduser --system --ingroup velociraptor --home /velociraptor --no-create-home --shell /bin/false velociraptor
    fi

    # Generate server config with Velociraptor defaults
    echo "Generating server configuration..."
    ${VELOCIRAPTOR_BIN} config generate > "${CONFIG_FILE}"

    # Patch config for container environment
    # Bind all interfaces so ports are reachable from outside the container
    sed -i 's/bind_address: 127.0.0.1/bind_address: 0.0.0.0/' "${CONFIG_FILE}"
    # Use our volume-mounted directories instead of /var/tmp/velociraptor
    sed -i "s|/var/tmp/velociraptor|${DATA_DIR}|g" "${CONFIG_FILE}"
    # Set log directory
    sed -i "s|output_directory: .*|output_directory: ${LOGS_DIR}|" "${CONFIG_FILE}"
    # Patch server URL so clients connect via the provided DNS name
    sed -i "s|https://localhost:8000/|https://${VR_SERVER_DNS}:8000/|g" "${CONFIG_FILE}"

    echo "Config generated at ${CONFIG_FILE} (server DNS: ${VR_SERVER_DNS})"

    # Set ownership for velociraptor user before creating admin (needs datastore access)
    chown -R velociraptor:velociraptor "${CONFIG_DIR}" "${DATA_DIR}" "${LOGS_DIR}"

    # Create admin user (password passed as positional argument)
    echo "Creating admin user..."
    runuser -u velociraptor -- ${VELOCIRAPTOR_BIN} user add admin admin --role administrator --config "${CONFIG_FILE}"
    echo "Admin user created (username: admin)"

    # Generate API config for querying the server
    API_CONFIG_FILE="${CONFIG_DIR}/api.config.yaml"
    echo "Generating API client config..."
    runuser -u velociraptor -- ${VELOCIRAPTOR_BIN} --config "${CONFIG_FILE}" \
        config api_client --name admin --role administrator "${API_CONFIG_FILE}"

    # Generate client packages by running server artifacts
    echo "Generating client installer packages..."
    echo "Starting server temporarily for artifact collection..."
    runuser -u velociraptor -- ${VELOCIRAPTOR_BIN} --config "${CONFIG_FILE}" frontend &
    SERVER_PID=$!

    # Wait for server to become ready (query via API)
    RETRIES=0
    MAX_RETRIES=30
    while ! runuser -u velociraptor -- ${VELOCIRAPTOR_BIN} --api_config "${API_CONFIG_FILE}" query "SELECT 1 FROM scope()" > /dev/null 2>&1; do
        RETRIES=$((RETRIES + 1))
        if [ $RETRIES -ge $MAX_RETRIES ]; then
            echo "WARNING: Server did not become ready in time. Skipping package generation."
            kill $SERVER_PID 2>/dev/null || true
            wait $SERVER_PID 2>/dev/null || true
            break
        fi
        sleep 2
    done

    if [ $RETRIES -lt $MAX_RETRIES ]; then
        echo "Server ready. Collecting artifacts..."

        echo "  Running Server.Utils.CreateLinuxPackages..."
        runuser -u velociraptor -- ${VELOCIRAPTOR_BIN} --api_config "${API_CONFIG_FILE}" \
            query "SELECT collect_client(client_id='server', artifacts='Server.Utils.CreateLinuxPackages') FROM scope()" \
            --max_wait 120 || \
            echo "  WARNING: Linux package generation failed (non-fatal)"

        echo "  Running Server.Utils.CreateMSI..."
        runuser -u velociraptor -- ${VELOCIRAPTOR_BIN} --api_config "${API_CONFIG_FILE}" \
            query "SELECT collect_client(client_id='server', artifacts='Server.Utils.CreateMSI') FROM scope()" \
            --max_wait 120 || \
            echo "  WARNING: MSI generation failed (non-fatal)"

        # Allow collections to complete
        echo "  Waiting for artifact collections to finish..."
        sleep 15

        echo "Stopping temporary server..."
        kill $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
    fi

    echo "Client package generation complete."

    echo "=== Initialization complete ==="
else
    echo "Existing config found at ${CONFIG_FILE} - skipping initialization"

    # Ensure velociraptor user exists on subsequent runs
    if ! getent group velociraptor > /dev/null 2>&1; then
        addgroup --system velociraptor
    fi
    if ! getent passwd velociraptor > /dev/null 2>&1; then
        adduser --system --ingroup velociraptor --home /velociraptor --no-create-home --shell /bin/false velociraptor
    fi

    # Fix ownership in case volumes were recreated
    chown -R velociraptor:velociraptor "${CONFIG_DIR}" "${DATA_DIR}" "${LOGS_DIR}"
fi

# Start Velociraptor frontend as the velociraptor user
echo "Starting Velociraptor frontend..."
exec runuser -u velociraptor -- ${VELOCIRAPTOR_BIN} --config "${CONFIG_FILE}" frontend
