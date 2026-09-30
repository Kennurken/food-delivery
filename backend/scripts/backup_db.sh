#!/usr/bin/env bash
# Dump the production database to a compressed file and keep the newest 14.
#
#   DATABASE_URL='postgresql://…' backend/scripts/backup_db.sh [target-dir]
#
# The URL comes from the environment and is never written anywhere. Neon also
# keeps a short point-in-time history, but that is a rewind button, not a
# backup: this file survives losing the Neon project.
set -euo pipefail

: "${DATABASE_URL:?set DATABASE_URL to the production connection string}"
dir="${1:-$HOME/food-delivery-backups}"
mkdir -p "$dir"
file="$dir/food-$(date -u +%Y%m%dT%H%M%SZ).sql.gz"

# psycopg URLs may carry a driver suffix that pg_dump does not understand.
pg_dump --no-owner --no-privileges "${DATABASE_URL/+psycopg/}" | gzip -9 > "$file"
test -s "$file"
echo "wrote $file ($(du -h "$file" | cut -f1))"

ls -1t "$dir"/food-*.sql.gz | tail -n +15 | xargs rm -f
