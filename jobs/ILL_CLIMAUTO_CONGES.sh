#!/bin/bash
# ILL_CLIMAUTO_CONGES - ECF_CLIMAUTO_RUN_CONGES - Illustration : cree une
# demande de conges reelle pour un employe de CLIM AUTO - approfondit le
# volet RH demande par le client (au-dela de la simple fiche employe).
# IN_COND=CONGES_ACTIVE|ILL_CLIMAUTO_EMPLOYES_OK.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

echo "[ILL_CLIMAUTO_CONGES] Creation d'une demande de conges CLIM AUTO..."
_odoo_shell_exec "
from datetime import date, timedelta
employe = env['hr.employee'].search([('name', '=', 'Traore Aminata')], limit=1)
assert employe, 'employe Traore Aminata introuvable - jouer ILL_CLIMAUTO_EMPLOYES d abord'
# 'Unpaid' choisi explicitement : requires_allocation=False (verifie en
# base) - contrairement a 'Paid Time Off' (le premier type trouve par un
# simple search([]) initial, qui exige une allocation de solde prealable
# et faisait echouer la creation - erreur reelle rencontree et corrigee).
LeaveType = env['hr.leave.type'].search([('name', '=', 'Unpaid')], limit=1)
assert LeaveType, 'type de conge Unpaid introuvable dans le registre'
Leave = env['hr.leave']
debut = date.today() + timedelta(days=14)
fin = debut + timedelta(days=4)
existant = Leave.search([('employee_id', '=', employe.id)], limit=1)
if not existant:
    Leave.create({
        'employee_id': employe.id,
        'holiday_status_id': LeaveType.id,
        'request_date_from': debut,
        'request_date_to': fin,
        'name': 'Conges annuels',
    })
    print('RESULTAT: demande de conges creee pour', employe.name)
else:
    print('RESULTAT: deja existant pour', employe.name)
env.cr.commit()
"

echo "[ILL_CLIMAUTO_CONGES] Verification reelle en base..."
NB="$(PGPASSWORD="$(read_or_generate_secret "$PG_ODOO_DB_PASSWORD_FILE" non)" psql -h 127.0.0.1 -U "${PG_ODOO_DB_USER}" -d "${PG_ODOO_DB_NAME}" -tAc "SELECT count(*) FROM hr_leave l JOIN hr_employee e ON e.id=l.employee_id WHERE e.name='Traore Aminata';")"
if [ "${NB:-0}" -lt 1 ]; then
  echo "[ILL_CLIMAUTO_CONGES] ERREUR : aucune demande de conges trouvee en base." >&2
  exit 1
fi

echo "[ILL_CLIMAUTO_CONGES] OK."
exit 0
