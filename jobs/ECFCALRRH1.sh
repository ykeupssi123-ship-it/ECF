#!/bin/bash
# ECFCALRRH1 - ECF_RH_CYC_FINCONTRAT - Cycle TFJ RH (voir
# bin/montee_au_plan.sh). IN_COND=TFJ_RH_WINDOW_OPEN. Chaine a UN SEUL
# job - terminal direct.
#
# Objectif metier reel : detecte les contrats (hr.contract) dont la date
# de fin (date_end) arrive dans moins de 30 jours - CDD ou periode
# d'essai proche de l'echeance, pour decider a temps du renouvellement
# ou de la fin. Champ date_end REEL en Odoo Community (verifie - seule
# la paie CALCULEE est Enterprise, pas cette donnee de date). Rapport
# ecrit dans $OPERATIONS_DIR/rh/snd (sous-dossier canonique).
# OUT_COND=TFJ_RH_TERMINE (REEL, remis a zero par montee_au_plan.sh le
# cycle suivant).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/rh/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/alerte_fin_contrat_$(date +%Y%m%d).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import date, timedelta
Contract = env['hr.contract']
aujourdhui = date.today()
horizon = aujourdhui + timedelta(days=30)
contrats = Contract.search([
    ('state', '=', 'open'),
    ('date_end', '!=', False),
    ('date_end', '>=', aujourdhui),
    ('date_end', '<=', horizon),
])
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['employe', 'date_fin_contrat', 'jours_restants'])
    for c in contrats:
        jours = (c.date_end - aujourdhui).days
        writer.writerow([c.employee_id.name, c.date_end, jours])
print('RESULTAT:', len(contrats))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_RH_CYC_FINCONTRAT] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_RH_CYC_FINCONTRAT] $COUNT contrat(s) arrivant a echeance sous 30 jours - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_RH_CYC_FINCONTRAT] Cycle TFJ RH TERMINE pour aujourd'hui."
exit 0
