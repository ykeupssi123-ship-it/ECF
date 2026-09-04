#!/bin/bash
# ECFRREC1 - ECF_CLIMAUTO_RUN_RECRUTEMENT - Illustration :
# cree une offre d'emploi reelle + un candidat pour CLIM AUTO -
# approfondit le volet RH demande par le client.
# IN_COND=RECRUTEMENT_ACTIVE|ILL_CLIMAUTO_SOCIETE_OK.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL_CLIMAUTO_RECRUTEMENT] Creation d'une offre + candidat CLIM AUTO..."
_odoo_shell_exec "
company = env['res.company'].search([('name', '=', 'CLIM AUTO')], limit=1)
assert company, 'societe CLIM AUTO introuvable - jouer ILL_CLIMAUTO_SOCIETE d abord'
Job = env['hr.job']
poste = Job.search([('name', '=', 'Mecanicien climatisation auto'), ('company_id', '=', company.id)], limit=1)
if not poste:
    poste = Job.create({
        'name': 'Mecanicien climatisation auto',
        'company_id': company.id,
        'no_of_recruitment': 1,
        'description': 'Diagnostic, reparation et entretien des systemes de climatisation automobile.',
    })
    print('RESULTAT: offre creee', poste.id)
else:
    print('RESULTAT: offre existante', poste.id)

Applicant = env['hr.applicant']
candidat = Applicant.search([('partner_name', '=', 'Diaby Moussa')], limit=1)
if not candidat:
    Applicant.create({
        'partner_name': 'Diaby Moussa',
        'email_from': 'moussa.diaby.candidat@gmail.com',
        'partner_phone': '+225 07 55 66 77 88',
        'job_id': poste.id,
    })
    print('RESULTAT: candidat cree')
else:
    print('RESULTAT: candidat existant')
env.cr.commit()
"

echo "[ILL_CLIMAUTO_RECRUTEMENT] Verification reelle en base..."
NB="$(PGPASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d "${PG_ODOO_DB_NAME}" -tAc "SELECT count(*) FROM hr_applicant WHERE partner_name='Diaby Moussa';")"
if [ "${NB:-0}" -lt 1 ]; then
  echo "[ILL_CLIMAUTO_RECRUTEMENT] ERREUR : candidat introuvable en base." >&2
  exit 1
fi

echo "[ILL_CLIMAUTO_RECRUTEMENT] OK."
exit 0
