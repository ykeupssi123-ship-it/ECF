#!/bin/bash
# ECFRSOC2 - ECF_COUL_RUN_SOCIETE - Illustration : cree la fiche
# societe reelle "COUL" (parfumerie, Plateau) dans Odoo - socle pour les
# jobs RH/CRM/facturation suivants pour ce client. Idempotent.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL_COUL_SOCIETE] Creation/verification de la societe COUL..."
_odoo_shell_exec "
company = env['res.company'].search([('name', '=', 'COUL')], limit=1)
if not company:
    # CORRIGE le 2026-09-02 (voir ILL_CLIMAUTO_SOCIETE.sh pour le detail
    # complet) : devise XOF fixee des la creation, jamais corrigeable
    # apres coup une fois des ecritures comptables postees.
    xof = env['res.currency'].search([('name', '=', 'XOF')], limit=1)
    company = env['res.company'].create({
        'name': 'COUL',
        'street': 'Avenue Chardy, Le Plateau',
        'city': 'Abidjan',
        'country_id': env.ref('base.ci').id,
        'currency_id': xof.id if xof else env.company.currency_id.id,
        'phone': '+225 27 20 31 55 07',
        'email': 'contact@coul.ci',
        'website': 'https://coul.ci',
    })
    print('RESULTAT: cree', company.id)
else:
    print('RESULTAT: existant', company.id)
env.cr.commit()
"

echo "[ILL_COUL_SOCIETE] Verification reelle en base..."
EXISTS="$(PGPASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d "${PG_ODOO_DB_NAME}" -tAc "SELECT 1 FROM res_company WHERE name='COUL';")"
if [ "$EXISTS" != "1" ]; then
  echo "[ILL_COUL_SOCIETE] ERREUR : societe COUL introuvable en base apres creation." >&2
  exit 1
fi

echo "[ILL_COUL_SOCIETE] OK."
exit 0
