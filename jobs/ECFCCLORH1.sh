#!/bin/bash
# ECFCCLORH1 - ECF_RH_CYC_EFFECTIFMENSUEL - Cycle EOM reel (voir
# bin/montee_au_plan.sh). IN_COND=RH_EFF_EOM_WINDOW_OPEN (ouverte le
# 1er du mois uniquement, montee_au_plan.sh - nom distinct de
# PRESENCES_EOM_WINDOW_OPEN, module different malgre la meme cadence).
# Chaine a UN SEUL job - terminal direct. OUT_COND=RH_EFF_EOM_TERMINE.
#
# Objectif metier reel : une fois par mois, combien d'employes actifs
# et depuis combien de temps (hr.employee, deja utilise indirectement
# via hr.contract par ECFCALRRH1) - photographie mensuelle des
# effectifs, base reelle du bilan social annuel (ECFCCLORH2).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/rh/$DOSSIER_PRODUIT"
mkdir -p "$SND_DIR"
RAPPORT="$SND_DIR/effectifs_anciennete_$(date +%Y%m).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import date
Employe = env['hr.employee']
actifs = Employe.search([('active', '=', True)])
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['employe', 'date_embauche', 'anciennete_jours'])
    for e in actifs:
        embauche = e.first_contract_date if hasattr(e, 'first_contract_date') else False
        anciennete = (date.today() - embauche).days if embauche else ''
        writer.writerow([e.name, embauche or 'INCONNUE', anciennete])
print('RESULTAT:', len(actifs))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_RH_CYC_EFFECTIFMENSUEL] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_RH_CYC_EFFECTIFMENSUEL] $COUNT employe(s) actif(s) - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_RH_CYC_EFFECTIFMENSUEL] Cycle EOM RH (effectifs) TERMINE pour ce mois."
exit 0
