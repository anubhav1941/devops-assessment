#!/bin/bash
set -euo pipefail

CONTAINER_NAME="hotel_bookings_db"
DB_USER="appadmin"
DB_NAME="appdb"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="${SCRIPT_DIR}/../backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/appdb_backup_${TIMESTAMP}.sql"

mkdir -p "$BACKUP_DIR"

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Error: container '${CONTAINER_NAME}' is not running. Start it with: docker compose up -d"
    exit 1
fi

docker exec "$CONTAINER_NAME" pg_dump -U "$DB_USER" -d "$DB_NAME" > "$BACKUP_FILE"

echo "Backup created: ${BACKUP_FILE}"
echo "Size: $(du -h "$BACKUP_FILE" | cut -f1)"
