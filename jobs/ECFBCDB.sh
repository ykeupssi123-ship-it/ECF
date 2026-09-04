#!/bin/bash
# ECFBCDB - ECF_ODOO_BLD_CREATEDB - Creation de la base
# du systeme Odoo (le "systeme ERP/CRM" lui-meme, base + web, AVANT tout
# module metier - les modules s'installent chacun par leur propre job,
# voir la serie CRM_0xx/VENTE_0xx/COMPTA_0xx etc.)
#
# --without-demo=all : jamais les fausses donnees de demo generiques
# d'Odoo - la demo reelle (garage, parfumerie ou autre) se construit
# avec de vraies donnees d'illustration via les jobs RUN dedies,
# jamais le jeu de donnees generique d'Odoo lui-meme.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

VENV_DIR="${ODOO_HOME}/venv"
SRC_DIR="${ODOO_HOME}/odoo-src"
PG_ODOO_DB_PASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)" || exit 1

DB_EXISTS=$(PGPASSWORD="$PG_ODOO_DB_PASSWORD" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${PG_ODOO_DB_NAME}'")
if [ "$DB_EXISTS" = "1" ]; then
  echo "[ODOO_014] Base ${PG_ODOO_DB_NAME} deja presente, ignore."
  echo "[ODOO_014] OK."
  exit 0
fi

echo "[ODOO_014] Arret temporaire du service (evite un conflit de port pendant l'initialisation)..."
systemctl stop odoo 2>/dev/null || true

echo "[ODOO_014] Creation et initialisation de la base ${PG_ODOO_DB_NAME} (modules base + web, sans donnees de demo generiques)..."
sudo -u "${ODOO_USER}" bash -c "source '${VENV_DIR}/bin/activate' && python3 '${SRC_DIR}/odoo-bin' -c '${ODOO_CONF}' -d '${PG_ODOO_DB_NAME}' -i base,web --without-demo=all --stop-after-init"

echo "[ODOO_014] Redemarrage du service..."
systemctl start odoo 2>/dev/null || true
if ! wait_for_service_active odoo 90 5; then
  echo "[ODOO_014] ERREUR : le service odoo n'a pas redemarre apres creation de la base." >&2
  journalctl -u odoo -n 40 --no-pager 2>/dev/null || true
  exit 1
fi

echo "[ODOO_014] Verification reelle : la base apparait dans le systeme..."
PG_ODOO_DB_PASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)"
DB_EXISTS_AFTER=$(PGPASSWORD="$PG_ODOO_DB_PASSWORD" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='${PG_ODOO_DB_NAME}'")
if [ "$DB_EXISTS_AFTER" != "1" ]; then
  echo "[ODOO_014] ERREUR : base ${PG_ODOO_DB_NAME} toujours absente apres initialisation." >&2
  exit 1
fi

echo "[ODOO_014] OK (base ${PG_ODOO_DB_NAME} creee et initialisee - le systeme Odoo est installe)."
exit 0
