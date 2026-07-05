#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <backup_file>"
    echo "Example: $0 ../backups/appdb_backup_20260706_120000.sql"
    exit 1
fi

BACKUP_FILE="$1"
CONTAINER_NAME="hotel_bookings_db"
DB_USER="appadmin"
RESTORE_DB_NAME="appdb_restore_test"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: backup file not found: ${BACKUP_FILE}"
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    echo "Error: container '${CONTAINER_NAME}' is not running. Start it with: docker compose up -d"
    exit 1
fi

docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS ${RESTORE_DB_NAME};"
docker exec "$CONTAINER_NAME" psql -U "$DB_USER" -d postgres -c "CREATE DATABASE ${RESTORE_DB_NAME};"

cat "$BACKUP_FILE" | docker exec -i "$CONTAINER_NAME" psql -v ON_ERROR_STOP=1 -U "$DB_USER" -d "$RESTORE_DB_NAME"

echo "Restore complete into database: ${RESTORE_DB_NAME}"
echo ""
echo "Verify with:"
echo "  docker exec -it ${CONTAINER_NAME} psql -U ${DB_USER} -d ${RESTORE_DB_NAME} -c \"SELECT COUNT(*) FROM hotel_bookings;\""
echo "  docker exec -it ${CONTAINER_NAME} psql -U ${DB_USER} -d ${RESTORE_DB_NAME} -c \"SELECT COUNT(*) FROM booking_events;\""
