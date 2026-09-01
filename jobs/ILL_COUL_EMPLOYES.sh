#!/bin/bash
# ILL_COUL_EMPLOYES - ECF_COUL_RUN_EMPLOYES - Illustration : cree une
# equipe fictive realiste pour COUL (parfumerie, Le Plateau) - reponse
# directe a la demande du client de mettre en avant le volet RH pendant
# la demo. IN_COND=RH_ACTIVE (voir ILL_CLIMAUTO_EMPLOYES.sh pour le detail
# du raisonnement de dependance).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL_COUL_EMPLOYES] Creation de l'equipe COUL..."
_odoo_shell_exec "
company = env['res.company'].search([('name', '=', 'COUL')], limit=1)
assert company, 'societe COUL introuvable - jouer ILL_COUL_SOCIETE d abord'
Employee = env['hr.employee']
equipe = [
    {'name': 'Diomande Marie-Claire', 'job_title': 'Responsable boutique', 'work_email': 'mc.diomande@coul.ci', 'work_phone': '+225 07 15 26 37 48'},
    {'name': 'Yao Prisca', 'job_title': 'Conseillere de vente', 'work_email': 'p.yao@coul.ci', 'work_phone': '+225 05 60 71 82 93'},
    {'name': 'Ouattara Ibrahim', 'job_title': 'Approvisionnement et stock', 'work_email': 'i.ouattara@coul.ci', 'work_phone': '+225 01 45 56 67 78'},
    {'name': 'Konan Grace', 'job_title': 'Comptabilite et facturation', 'work_email': 'g.konan@coul.ci', 'work_phone': '+225 07 33 44 55 66'},
]
cree = 0
for e in equipe:
    if not Employee.search([('name', '=', e['name']), ('company_id', '=', company.id)]):
        e['company_id'] = company.id
        Employee.create(e)
        cree += 1
env.cr.commit()
print('RESULTAT:', cree, 'nouveaux employes crees')
"

echo "[ILL_COUL_EMPLOYES] Verification reelle en base..."
NB="$(PGPASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d "${PG_ODOO_DB_NAME}" -tAc "SELECT count(*) FROM hr_employee e JOIN res_company c ON c.id=e.company_id WHERE c.name='COUL';")"
if [ "${NB:-0}" -lt 4 ]; then
  echo "[ILL_COUL_EMPLOYES] ERREUR : seulement ${NB:-0}/4 employes trouves en base." >&2
  exit 1
fi

echo "[ILL_COUL_EMPLOYES] OK (${NB} employes COUL en base)."
exit 0
