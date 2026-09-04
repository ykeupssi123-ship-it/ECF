#!/bin/bash
# ECFRCRM2 - ECF_COUL_RUN_CRMPISTES - Illustration : cree un
# pipeline commercial fictif realiste pour COUL (parfumerie - vente
# detail et grossiste) - reponse directe a la demande du client de
# mettre en avant le volet CRM. IN_COND=CRM_ACTIVE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL_COUL_CRM_PISTES] Creation du pipeline CRM COUL..."
_odoo_shell_exec "
company = env['res.company'].search([('name', '=', 'COUL')], limit=1)
assert company, 'societe COUL introuvable - jouer ILL_COUL_SOCIETE d abord'
Lead = env['crm.lead']
stage_new = env['crm.stage'].search([('name', '=', 'New')], limit=1)
stage_qualified = env['crm.stage'].search([('name', '=', 'Qualified')], limit=1)
stage_won = env['crm.stage'].search([('name', '=', 'Won')], limit=1)

pistes = [
    {'name': 'Commande grossiste - 200 flacons parfum femme', 'partner_name': 'Beaute Ivoire Distribution', 'contact_name': 'Diabate Rokia', 'phone': '+225 07 44 55 66 77', 'expected_revenue': 1200000, 'probability': 40, 'stage_id': stage_qualified.id if stage_qualified else False},
    {'name': 'Ouverture compte pro - Salon de coiffure Eclat', 'partner_name': 'Salon Eclat', 'contact_name': 'Toure Salimata', 'phone': '+225 05 88 99 00 11', 'expected_revenue': 350000, 'probability': 20, 'stage_id': stage_new.id if stage_new else False},
    {'name': 'Coffret cadeau entreprise - fin d annee', 'partner_name': 'Groupe Atlantique Assurances', 'contact_name': 'Kacou Delphine', 'phone': '+225 01 33 22 11 00', 'expected_revenue': 600000, 'probability': 60, 'stage_id': stage_qualified.id if stage_qualified else False},
    {'name': 'Vente parfum homme edition limitee', 'partner_name': 'Brou Christian (particulier)', 'contact_name': 'Brou Christian', 'phone': '+225 07 12 23 34 45', 'expected_revenue': 45000, 'probability': 100, 'stage_id': stage_won.id if stage_won else False},
]
cree = 0
for p in pistes:
    if not Lead.search([('name', '=', p['name']), ('company_id', '=', company.id)]):
        p['company_id'] = company.id
        p['type'] = 'opportunity'
        Lead.create(p)
        cree += 1
env.cr.commit()
print('RESULTAT:', cree, 'nouvelles pistes creees')
"

echo "[ILL_COUL_CRM_PISTES] Verification reelle en base..."
NB="$(PGPASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d "${PG_ODOO_DB_NAME}" -tAc "SELECT count(*) FROM crm_lead l JOIN res_company c ON c.id=l.company_id WHERE c.name='COUL';")"
if [ "${NB:-0}" -lt 4 ]; then
  echo "[ILL_COUL_CRM_PISTES] ERREUR : seulement ${NB:-0}/4 pistes trouvees en base." >&2
  exit 1
fi

echo "[ILL_COUL_CRM_PISTES] OK (${NB} pistes COUL en base)."
exit 0
