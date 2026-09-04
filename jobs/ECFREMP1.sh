#!/bin/bash
# ECFREMP1 - ECF_ILL1_RUN_EMPLOYES - Illustration : cree
# une equipe fictive realiste pour CLIM AUTO (garage/atelier climatisation
# auto, Cocody) - reponse directe a la demande du client de mettre en
# avant le volet RH pendant la demo. IN_COND=RH_ACTIVE : ne joue que si
# l'operateur a deja active le module RH devant le client (les donnees
# restent en base meme si le module est ensuite desactive - elles
# reapparaissent immediatement a la reactivation).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL1_EMPLOYES] Creation de l'equipe CLIM AUTO..."
_odoo_shell_exec "
company = env['res.company'].search([('name', '=', 'CLIM AUTO')], limit=1)
assert company, 'societe CLIM AUTO introuvable - jouer ILL1_SOCIETE d abord'
Employee = env['hr.employee']
equipe = [
    {'name': 'Kouadio Yao Bertin', 'job_title': 'Chef d atelier', 'work_email': 'b.kouadio@climauto.ci', 'work_phone': '+225 07 08 12 34 56'},
    {'name': 'Traore Aminata', 'job_title': 'Accueil et reception client', 'work_email': 'a.traore@climauto.ci', 'work_phone': '+225 05 44 67 89 01'},
    {'name': 'N Guessan Serge', 'job_title': 'Mecanicien climatisation', 'work_email': 's.nguessan@climauto.ci', 'work_phone': '+225 01 22 33 44 55'},
    {'name': 'Kone Fatoumata', 'job_title': 'Comptabilite et facturation', 'work_email': 'f.kone@climauto.ci', 'work_phone': '+225 07 99 88 77 66'},
    {'name': 'Bamba Souleymane', 'job_title': 'Mecanicien polyvalent', 'work_email': 's.bamba@climauto.ci', 'work_phone': '+225 05 11 22 33 44'},
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

echo "[ILL1_EMPLOYES] Verification reelle en base..."
NB="$(PGPASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d "${PG_ODOO_DB_NAME}" -tAc "SELECT count(*) FROM hr_employee e JOIN res_company c ON c.id=e.company_id WHERE c.name='CLIM AUTO';")"
if [ "${NB:-0}" -lt 5 ]; then
  echo "[ILL1_EMPLOYES] ERREUR : seulement ${NB:-0}/5 employes trouves en base." >&2
  exit 1
fi

echo "[ILL1_EMPLOYES] OK (${NB} employes CLIM AUTO en base)."
exit 0
