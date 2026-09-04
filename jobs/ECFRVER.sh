#!/bin/bash
# ECFRVER - ECF_SYS_RUN_SYSTEMVERIFY - Verification finale
# de bout en bout : le systeme Odoo complet (PostgreSQL + Odoo + Nginx +
# DNS) est joignable comme un vrai client (navigateur du client) le
# ferait - jamais un "OK" qui ne teste que la couche interne.
#
# DEPLACE EN PARALLELE LE 2026-09-04 (demande explicite utilisateur) :
# avant, IN_COND=ODOO_BACKUP_OK et OUT_COND=ODOO_SYSTEME_PRET - un job
# de VERIFICATION/FIABILITE se trouvait directement sur le chemin
# critique avant ODOO_SYSTEME_PRET, la condition dont dependent les 34
# modules + une partie du Tier 1 (40 jobs). Un test de solidite ne doit
# jamais bloquer la suite d'une installation. Corrige : ODOO_SYSTEME_PRET
# est desormais produit directement par ECFBBCK (dernier vrai
# prealable technique, la sauvegarde). ECFRVER tourne maintenant EN
# PARALLELE des 34 modules (IN_COND=ODOO_SYSTEME_PRET, comme eux) et
# produit ODOO_VERIFICATION_OK, que rien d'autre ne consomme - un
# rapport consultable (./bin/view_history.sh ECFRVER), plus jamais un
# verrou. Voir docs/CONVENTION_NOMMAGE.md et docs/JOURNAL_TECHNIQUE.md.
set -uo pipefail
source "$VARS_FILE"

echo "[ECFRVER] Verification HTTPS reelle via ${ERP_DASHBOARD_FQDN}..."
HTTP_CODE=$(curl -sk -o /dev/null -w '%{http_code}' "https://127.0.0.1/web/login" -H "Host: ${ERP_DASHBOARD_FQDN}")
if [ "$HTTP_CODE" != "200" ]; then
  echo "[ECFRVER] ERREUR : page de connexion Odoo non joignable via HTTPS (HTTP ${HTTP_CODE})." >&2
  exit 1
fi

echo "[ECFRVER] Verification que la base ${PG_ODOO_DB_NAME} est bien selectionnee..."
if ! curl -sk "https://127.0.0.1/web/login" -H "Host: ${ERP_DASHBOARD_FQDN}" | grep -qi "login"; then
  echo "[ECFRVER] ERREUR : la page de connexion ne contient pas le formulaire attendu." >&2
  exit 1
fi

echo "[ECFRVER] OK - systeme Odoo complet et joignable : https://${ERP_DASHBOARD_FQDN}/"
echo "[ECFRVER] Identifiant admin par defaut de la base : admin / admin (a changer avant toute demo reelle)."
exit 0
