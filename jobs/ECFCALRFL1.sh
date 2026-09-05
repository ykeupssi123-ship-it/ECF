#!/bin/bash
# ECFCALRFL1 - ECF_FLEET_CYC_ALERTEECHEANCE - Cycle JOUR reel (voir
# bin/montee_au_plan.sh). IN_COND=FLOTTE_JOUR_WINDOW_OPEN (ouverte
# uniquement par montee_au_plan.sh, une fois par jour - meme mecanisme
# DAILY que les cycles TFJ, cadence "JOUR" au sens metier plutot que
# "fin de journee"). Chaine a UN SEUL job - terminal direct.
# OUT_COND=FLOTTE_JOUR_TERMINE.
#
# Objectif metier reel : alerte avant qu'une assurance ou qu'un
# controle technique n'expire, via fleet.vehicle.log.contract
# (application Fleet, suivi des contrats vehicule - disponible en
# Community pour le suivi de base ; A CONFIRMER SUR LA VM REELLE si
# le champ 'expiration_date' se comporte comme attendu, jamais
# suppose au-dela de ce point - meme discipline que pour ECFRAHRC).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/fl/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"
RAPPORT="$SND_DIR/alerte_echeance_$(date +%Y%m%d).csv"
HORIZON_JOURS="${FLOTTE_ALERTE_HORIZON_JOURS:-30}"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import date, timedelta
Contrat = env['fleet.vehicle.log.contract']
aujourdhui = date.today()
horizon = aujourdhui + timedelta(days=${HORIZON_JOURS})
contrats = Contrat.search([
    ('state', '=', 'open'),
    ('expiration_date', '!=', False),
    ('expiration_date', '<=', horizon),
])
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['vehicule', 'type_contrat', 'date_echeance', 'jours_restants'])
    for c in contrats:
        jours = (c.expiration_date - aujourdhui).days
        writer.writerow([c.vehicle_id.name if c.vehicle_id else '', c.cost_subtype_id.name if c.cost_subtype_id else '', c.expiration_date, jours])
print('RESULTAT:', len(contrats))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_FLEET_CYC_ALERTEECHEANCE] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_FLEET_CYC_ALERTEECHEANCE] $COUNT contrat(s) vehicule arrivant a echeance sous ${HORIZON_JOURS} jours - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_FLEET_CYC_ALERTEECHEANCE] Cycle JOUR Flotte TERMINE pour aujourd'hui."
exit 0
