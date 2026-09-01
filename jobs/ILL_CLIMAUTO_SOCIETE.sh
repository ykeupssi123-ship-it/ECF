#!/bin/bash
# ILL_CLIMAUTO_SOCIETE - ECF_CLIMAUTO_RUN_SOCIETE - Illustration : cree la
# fiche societe reelle "CLIM AUTO" (garage/atelier, Cocody) dans Odoo -
# socle sur lequel s'appuient les jobs RH/CRM/facturation suivants pour
# ce client. Idempotent (recherche par nom avant creation).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL_CLIMAUTO_SOCIETE] Creation/verification de la societe CLIM AUTO..."
_odoo_shell_exec "
company = env['res.company'].search([('name', '=', 'CLIM AUTO')], limit=1)
if not company:
    company = env['res.company'].create({
        'name': 'CLIM AUTO',
        'street': 'Boulevard Latrille, Cocody',
        'city': 'Abidjan',
        'country_id': env.ref('base.ci').id,
        'phone': '+225 27 22 44 18 90',
        'email': 'contact@climauto.ci',
        'website': 'https://climauto.ci',
    })
    print('RESULTAT: cree', company.id)
else:
    print('RESULTAT: existant', company.id)
env.cr.commit()
"

echo "[ILL_CLIMAUTO_SOCIETE] Verification reelle en base..."
EXISTS="$(PGPASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d "${PG_ODOO_DB_NAME}" -tAc "SELECT 1 FROM res_company WHERE name='CLIM AUTO';")"
if [ "$EXISTS" != "1" ]; then
  echo "[ILL_CLIMAUTO_SOCIETE] ERREUR : societe CLIM AUTO introuvable en base apres creation." >&2
  exit 1
fi

echo "[ILL_CLIMAUTO_SOCIETE] OK."
exit 0
