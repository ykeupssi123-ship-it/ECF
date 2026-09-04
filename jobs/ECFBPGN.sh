#!/bin/bash
# ECFBPGN - ECF_ODOO_BLD_PGINIT - Initialisation et
# demarrage de PostgreSQL
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

PGV="${PG_VERSION:-16}"
PGBIN="/usr/pgsql-${PGV}/bin"
PGDATA_SVC="postgresql-${PGV}"

if [ -f "/var/lib/pgsql/${PGV}/data/PG_VERSION" ]; then
  echo "[ODOO_004] Cluster PostgreSQL deja initialise, ignore."
else
  echo "[ODOO_004] Initialisation du cluster PostgreSQL ${PGV}..."
  "${PGBIN}/postgresql-${PGV}-setup" initdb
fi

echo "[ODOO_004] Demarrage de ${PGDATA_SVC}..."
systemctl enable "${PGDATA_SVC}" 2>/dev/null || true
systemctl restart "${PGDATA_SVC}" 2>/dev/null || true

if ! wait_for_service_active "${PGDATA_SVC}" 60 5; then
  echo "[ODOO_004] ERREUR : ${PGDATA_SVC} n'a pas demarre." >&2
  exit 1
fi

echo "[ODOO_004] OK."
exit 0
