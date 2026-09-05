#!/bin/bash
# ECFCPJFA1 - ECF_PROJETS_CYC_FACTURATION - Facturation au temps passe
# mensuelle (voir bin/montee_au_plan.sh, cadence MONTHLY,
# IN_COND=PROJETS_EOM_WINDOW_OPEN - ouverte le 1er de chaque mois, pour
# le mois qui vient de se terminer).
#
# Objectif metier reel : consolide les heures de temps passe
# (account.analytic.line, issues des feuilles de temps du module
# project) par projet pour le mois ecoule - base de facturation client,
# jamais une facture generee automatiquement (decision humaine, meme
# principe que ECFCVTRL/ECFCAHRA1 : ce job PROPOSE une base chiffree, ne
# declenche jamais lui-meme un acte commercial/financier). Rapport ecrit
# dans $OPERATIONS_DIR/pj/snd (sous-dossier canonique).
# OUT_COND=PROJETS_EOM_TERMINE (remis a zero par montee_au_plan.sh le
# mois suivant).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/pj/snd"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/facturation_temps_passe_$(date +%Y%m).csv"

RESULTAT="$(_odoo_shell_exec "
import calendar
import csv
from collections import defaultdict
from datetime import date

aujourdhui = date.today()
if aujourdhui.month == 1:
    mois_prec, annee_prec = 12, aujourdhui.year - 1
else:
    mois_prec, annee_prec = aujourdhui.month - 1, aujourdhui.year
premier_jour = date(annee_prec, mois_prec, 1)
dernier_jour = date(annee_prec, mois_prec, calendar.monthrange(annee_prec, mois_prec)[1])

Line = env['account.analytic.line']
lignes = Line.search([
    ('date', '>=', premier_jour),
    ('date', '<=', dernier_jour),
    ('project_id', '!=', False),
])
par_projet = defaultdict(float)
for l in lignes:
    par_projet[l.project_id.name] += l.unit_amount

with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['projet', 'heures_passees_mois'])
    for nom, heures in sorted(par_projet.items(), key=lambda x: -x[1]):
        writer.writerow([nom, f'{heures:.2f}'])
print('RESULTAT:', len(par_projet))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_PROJETS_CYC_FACTURATION] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_PROJETS_CYC_FACTURATION] Base de facturation ecrite pour $COUNT projet(s) du mois ecoule : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
exit 0
