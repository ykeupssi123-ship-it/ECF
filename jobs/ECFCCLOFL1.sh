#!/bin/bash
# ECFCCLOFL1 - ECF_FLEET_CYC_ENTRETIENMENSUEL - Cycle EOM reel (voir
# bin/montee_au_plan.sh). IN_COND=FLOTTE_EOM_WINDOW_OPEN (ouverte le
# 1er du mois uniquement, montee_au_plan.sh). Chaine a UN SEUL job -
# terminal direct. OUT_COND=FLOTTE_EOM_TERMINE.
#
# Objectif metier reel : une fois par mois, liste les vehicules dont
# le prochain entretien planifie (fleet.vehicle.log.services, date de
# service) est deja depasse ou tombe dans les 30 prochains jours -
# meme modele fleet deja utilise par ECFCALRFL1 pour les contrats.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/fl/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"
RAPPORT="$SND_DIR/controle_entretien_$(date +%Y%m).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import date, timedelta
Vehicule = env['fleet.vehicle']
horizon = date.today() + timedelta(days=30)
vehicules = Vehicule.search([])
a_verifier = []
for v in vehicules:
    services = env['fleet.vehicle.log.services'].search([('vehicle_id', '=', v.id)], order='date desc', limit=1)
    derniere_date = services.date if services else False
    a_verifier.append((v, derniere_date))
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['vehicule', 'dernier_entretien', 'a_verifier'])
    total = 0
    for v, derniere_date in a_verifier:
        besoin = (not derniere_date) or derniere_date <= horizon
        if besoin:
            total += 1
        writer.writerow([v.name, derniere_date or 'JAMAIS', besoin])
print('RESULTAT:', len(vehicules), total)
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_FLEET_CYC_ENTRETIENMENSUEL] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_FLEET_CYC_ENTRETIENMENSUEL] $COUNT vehicule(s) au total, rapport ecrit : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_FLEET_CYC_ENTRETIENMENSUEL] Cycle EOM Flotte TERMINE pour ce mois."
exit 0
