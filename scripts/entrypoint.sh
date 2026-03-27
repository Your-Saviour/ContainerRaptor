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

    echo "Config generated at ${CONFIG_FILE}"

    # Set ownership for velociraptor user before creating admin (needs datastore access)
    chown -R velociraptor:velociraptor "${CONFIG_DIR}" "${DATA_DIR}" "${LOGS_DIR}"

    # Create admin user (password passed as positional argument)
    echo "Creating admin user..."
    runuser -u velociraptor -- ${VELOCIRAPTOR_BIN} user add admin admin --role administrator --config "${CONFIG_FILE}"
    echo "Admin user created (username: admin)"

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
