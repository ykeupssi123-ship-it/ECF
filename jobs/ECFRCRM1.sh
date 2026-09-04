#!/bin/bash
# ECFRCRM1 - ECF_CLIMAUTO_RUN_CRMPISTES - Illustration :
# cree un pipeline commercial fictif realiste pour CLIM AUTO (garage,
# reparation/entretien climatisation auto) - reponse directe a la
# demande du client de mettre en avant le volet CRM. Pistes a des stades
# varies (nouveau, qualifie, gagne, perdu) pour montrer un pipeline
# vivant, pas une liste plate. IN_COND=CRM_ACTIVE.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL_CLIMAUTO_CRM_PISTES] Creation du pipeline CRM CLIM AUTO..."
_odoo_shell_exec "
company = env['res.company'].search([('name', '=', 'CLIM AUTO')], limit=1)
assert company, 'societe CLIM AUTO introuvable - jouer ILL_CLIMAUTO_SOCIETE d abord'
Lead = env['crm.lead']
stage_new = env['crm.stage'].search([('name', '=', 'New')], limit=1)
stage_qualified = env['crm.stage'].search([('name', '=', 'Qualified')], limit=1)
stage_won = env['crm.stage'].search([('name', '=', 'Won')], limit=1)

pistes = [
    {'name': 'Revision climatisation - Toyota Hilux', 'partner_name': 'Transport Confiance SARL', 'contact_name': 'Yao Michel', 'phone': '+225 07 08 55 21 33', 'expected_revenue': 85000, 'probability': 20, 'stage_id': stage_new.id if stage_new else False},
    {'name': 'Diagnostic panne clim - Hyundai Tucson', 'partner_name': 'Ouattara Ibrahim (particulier)', 'contact_name': 'Ouattara Ibrahim', 'phone': '+225 05 44 12 09 87', 'expected_revenue': 25000, 'probability': 50, 'stage_id': stage_qualified.id if stage_qualified else False},
    {'name': 'Contrat entretien flotte - 8 vehicules', 'partner_name': 'Ivoire Logistique', 'contact_name': 'Kouassi Edwige', 'phone': '+225 01 66 77 88 99', 'expected_revenue': 480000, 'probability': 80, 'stage_id': stage_qualified.id if stage_qualified else False},
    {'name': 'Recharge gaz climatisation - Peugeot 308', 'partner_name': 'Coulibaly Ange (particulier)', 'contact_name': 'Coulibaly Ange', 'phone': '+225 07 20 30 40 50', 'expected_revenue': 18000, 'probability': 100, 'stage_id': stage_won.id if stage_won else False},
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

echo "[ILL_CLIMAUTO_CRM_PISTES] Verification reelle en base..."
NB="$(PGPASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d "${PG_ODOO_DB_NAME}" -tAc "SELECT count(*) FROM crm_lead l JOIN res_company c ON c.id=l.company_id WHERE c.name='CLIM AUTO';")"
if [ "${NB:-0}" -lt 4 ]; then
  echo "[ILL_CLIMAUTO_CRM_PISTES] ERREUR : seulement ${NB:-0}/4 pistes trouvees en base." >&2
  exit 1
fi

echo "[ILL_CLIMAUTO_CRM_PISTES] OK (${NB} pistes CLIM AUTO en base)."
exit 0
