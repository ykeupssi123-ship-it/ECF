#!/bin/bash
# ECFBPGR - ECF_ODOO_BLD_PGROLE - Role PostgreSQL
# dedie a Odoo (CREATEDB - Odoo cree ses propres bases a la demande,
# comportement natif, jamais une seule base fixe imposee)
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

PGV="${PG_VERSION:-16}"
PG_HBA="/var/lib/pgsql/${PGV}/data/pg_hba.conf"
PG_ODOO_DB_PASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" oui)" || exit 1

echo "[ODOO_005] Verification/creation du role PostgreSQL ${PG_ODOO_DB_USER}..."
ROLE_EXISTS=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='${PG_ODOO_DB_USER}'")
if [ "$ROLE_EXISTS" = "1" ]; then
  echo "[ODOO_005] Role deja present, mise a jour du mot de passe..."
  sudo -u postgres psql -c "ALTER ROLE ${PG_ODOO_DB_USER} WITH PASSWORD '${PG_ODOO_DB_PASSWORD}';" >/dev/null
else
  sudo -u postgres psql -c "CREATE ROLE ${PG_ODOO_DB_USER} WITH LOGIN CREATEDB PASSWORD '${PG_ODOO_DB_PASSWORD}';" >/dev/null
fi

echo "[ODOO_005] Verification que l'authentification par mot de passe (scram-sha-256) est active pour les connexions locales..."
if ! grep -qE '^host\s+all\s+all\s+127\.0\.0\.1/32\s+scram-sha-256' "$PG_HBA" 2>/dev/null; then
  echo "[ODOO_005] Ajout d'une regle pg_hba.conf pour l'authentification par mot de passe en local..."
  echo "host    all             all             127.0.0.1/32            scram-sha-256" >> "$PG_HBA"
  systemctl restart "postgresql-${PGV}"
  if ! wait_for_service_active "postgresql-${PGV}" 60 5; then
    echo "[ODOO_005] ERREUR : PostgreSQL n'a pas redemarre apres modification de pg_hba.conf." >&2
    exit 1
  fi
fi

echo "[ODOO_005] Verification reelle de la connexion avec le nouveau role..."
if ! PGPASSWORD="$PG_ODOO_DB_PASSWORD" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d postgres -tAc "SELECT 1" | grep -q 1; then
  echo "[ODOO_005] ERREUR : connexion avec le role ${PG_ODOO_DB_USER} a echoue apres configuration." >&2
  exit 1
fi

echo "[ODOO_005] OK (connexion verifiee en reel)."
exit 0
