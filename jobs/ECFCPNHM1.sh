#!/bin/bash
# ECFCPNHM1 - ECF_PRESENCES_CYC_HEURESMOIS - Calcul mensuel des heures
# travaillees (voir bin/montee_au_plan.sh, cadence MONTHLY,
# IN_COND=PRESENCES_EOM_WINDOW_OPEN - ouverte le 1er de chaque mois, pour
# le mois qui vient de se terminer).
#
# DEPENDANCE METIER REELLE (catalogue, colonne "Depend de") : ce calcul
# s'appuie sur un rapport quotidien de presences/anomalies qui n'est pas
# encore construit - meme raisonnement documente que ECFCCPEM1
# (Comptabilite) vis-a-vis du cycle TFJ quotidien : dependance METIER,
# jamais une IN_COND technique (voir ECFCCPEM1.sh pour l'explication
# complete). Ce job fonctionne des maintenant de facon autonome, a
# partir des pointages reels (hr.attendance) - le rapport quotidien
# viendra enrichir l'exploitation plus tard, sans etre un prealable
# technique bloquant.
#
# Objectif metier reel : total des heures pointees (hr.attendance,
# check_in/check_out) par employe pour le mois ecoule - base de calcul
# pour la paie (le calcul de la PAIE elle-meme reste Enterprise, ce
# rapport ne fait que consolider le pointage reel, deja disponible en
# Community). Rapport ecrit dans $OPERATIONS_DIR/pn/snd (sous-dossier
# canonique). OUT_COND=PRESENCES_EOM_TERMINE (remis a zero par
# montee_au_plan.sh le mois suivant).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/pn/snd"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/heures_travaillees_$(date +%Y%m).csv"

RESULTAT="$(_odoo_shell_exec "
import calendar
import csv
from collections import defaultdict
from datetime import date, datetime, time

aujourdhui = date.today()
if aujourdhui.month == 1:
    mois_prec, annee_prec = 12, aujourdhui.year - 1
else:
    mois_prec, annee_prec = aujourdhui.month - 1, aujourdhui.year
premier_jour = datetime.combine(date(annee_prec, mois_prec, 1), time.min)
dernier_jour = datetime.combine(date(annee_prec, mois_prec, calendar.monthrange(annee_prec, mois_prec)[1]), time.max)

Attendance = env['hr.attendance']
pointages = Attendance.search([
    ('check_in', '>=', premier_jour),
    ('check_in', '<=', dernier_jour),
    ('check_out', '!=', False),
])
heures_par_employe = defaultdict(float)
for p in pointages:
    heures_par_employe[p.employee_id.name] += p.worked_hours

with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['employe', 'heures_travaillees_mois'])
    for nom, heures in sorted(heures_par_employe.items()):
        writer.writerow([nom, f'{heures:.2f}'])
print('RESULTAT:', len(heures_par_employe))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_PRESENCES_CYC_HEURESMOIS] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_PRESENCES_CYC_HEURESMOIS] Heures calculees pour $COUNT employe(s) du mois ecoule : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
