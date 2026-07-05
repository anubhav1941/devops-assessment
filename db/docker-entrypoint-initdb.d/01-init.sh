#!/bin/bash
set -euo pipefail

echo ">>> Running schema migrations..."
for f in /migrations/*.sql; do
    echo "    applying $f"
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$f"
done

echo ">>> Running seed data..."
for f in /seed/*.sql; do
    echo "    applying $f"
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -f "$f"
done

echo ">>> Database initialized: schema + seed data loaded."
