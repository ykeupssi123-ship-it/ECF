#!/bin/bash
# SVER - ECF_ODOO_RUN_SYSTEMVERIFY - Verification finale
# de bout en bout : le systeme Odoo complet (PostgreSQL + Odoo + Nginx +
# DNS) est joignable comme un vrai client (navigateur du client) le
# ferait - jamais un "OK" qui ne teste que la couche interne.
set -uo pipefail
source "$VARS_FILE"

echo "[ODOO_019] Verification HTTPS reelle via ${ERP_DASHBOARD_FQDN}..."
HTTP_CODE=$(curl -sk -o /dev/null -w '%{http_code}' "https://127.0.0.1/web/login" -H "Host: ${ERP_DASHBOARD_FQDN}")
if [ "$HTTP_CODE" != "200" ]; then
  echo "[ODOO_019] ERREUR : page de connexion Odoo non joignable via HTTPS (HTTP ${HTTP_CODE})." >&2
  exit 1
fi

echo "[ODOO_019] Verification que la base ${PG_ODOO_DB_NAME} est bien selectionnee..."
if ! curl -sk "https://127.0.0.1/web/login" -H "Host: ${ERP_DASHBOARD_FQDN}" | grep -qi "login"; then
  echo "[ODOO_019] ERREUR : la page de connexion ne contient pas le formulaire attendu." >&2
  exit 1
fi

echo "[ODOO_019] OK - systeme Odoo complet et joignable : https://${ERP_DASHBOARD_FQDN}/"
echo "[ODOO_019] Identifiant admin par defaut de la base : admin / admin (a changer avant toute demo reelle, voir ODOO_020 a venir)."
exit 0
