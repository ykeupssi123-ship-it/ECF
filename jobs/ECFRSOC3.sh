#!/bin/bash
# ECFRSOC3 - ECF_BOULANGERIE_RUN_SOCIETE - Illustration :
# 3e client prospect (boulangerie-glacier reelle rencontree par le
# client Ankrr, dont le comptable tient stock+comptabilite sur Excel) -
# cree la fiche societe "PAIN & GLACE" pour montrer le potentiel d'Odoo
# a son niveau.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL_BOULANGERIE_SOCIETE] Creation/verification de la societe PAIN & GLACE..."
_odoo_shell_exec "
company = env['res.company'].search([('name', '=', 'PAIN & GLACE')], limit=1)
if not company:
    # CORRIGE le 2026-09-02 (voir ILL_CLIMAUTO_SOCIETE.sh pour le detail
    # complet) : devise XOF fixee des la creation, jamais corrigeable
    # apres coup une fois des ecritures comptables postees.
    xof = env['res.currency'].search([('name', '=', 'XOF')], limit=1)
    company = env['res.company'].create({
        'name': 'PAIN & GLACE',
        'street': 'Rue du Commerce, Yopougon',
        'city': 'Abidjan',
        'country_id': env.ref('base.ci').id,
        'currency_id': xof.id if xof else env.company.currency_id.id,
        'phone': '+225 27 23 45 67 89',
        'email': 'contact@painetglace.ci',
    })
    print('RESULTAT: cree', company.id)
else:
    print('RESULTAT: existant', company.id)
env.cr.commit()
"

echo "[ILL_BOULANGERIE_SOCIETE] Verification reelle en base..."
EXISTS="$(PGPASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d "${PG_ODOO_DB_NAME}" -tAc "SELECT 1 FROM res_company WHERE name='PAIN & GLACE';")"
if [ "$EXISTS" != "1" ]; then
  echo "[ILL_BOULANGERIE_SOCIETE] ERREUR : societe introuvable en base apres creation." >&2
  exit 1
fi

echo "[ILL_BOULANGERIE_SOCIETE] OK."
exit 0
