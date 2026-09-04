#!/bin/bash
# SSVC - ECF_ODOO_BLD_START - Premier demarrage reel
# du service Odoo (sans base de donnees encore - juste le processus)
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ODOO_013] Demarrage du service odoo..."
systemctl restart odoo 2>/dev/null || true

if ! wait_for_service_active odoo 90 5; then
  echo "[ODOO_013] ERREUR : le service odoo n'a pas demarre. Diagnostic :" >&2
  journalctl -u odoo -n 40 --no-pager 2>/dev/null || true
  tail -n 40 /var/log/odoo/odoo.log 2>/dev/null || true
  exit 1
fi

echo "[ODOO_013] Verification reelle : le port ${ODOO_PORT} repond..."
sleep 3
if ! curl -sf -o /dev/null "http://127.0.0.1:${ODOO_PORT}/web/database/selector"; then
  echo "[ODOO_013] ERREUR : le port ${ODOO_PORT} ne repond pas HTTP correctement." >&2
  tail -n 40 /var/log/odoo/odoo.log 2>/dev/null || true
  exit 1
fi

echo "[ODOO_013] OK (service actif, port ${ODOO_PORT} repond)."
exit 0
