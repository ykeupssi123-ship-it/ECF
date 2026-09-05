#!/bin/bash
# ECFCCRRL1 - ECF_CRM_CYC_RELANCE - Cycle TFJ CRM (voir bin/montee_au_plan.sh,
# meme patron que le cycle TFJ Ventes). IN_COND=TFJ_CRM_WINDOW_OPEN (ouverte
# uniquement par montee_au_plan.sh, une fois par jour). Chaine a UN SEUL
# job (contrairement au cycle Ventes a 3) - job terminal direct.
#
# Objectif metier reel : detecte les pistes commerciales (crm.lead,
# type=lead, jamais converties en opportunite) dont personne n'a touche
# le dossier (write_date) depuis plus de 7 jours - un dossier oublie
# perd sa valeur commerciale. Rapport ecrit dans
# $OPERATIONS_DIR/cr/snd (sous-dossier canonique, voir jobs/ECFBOPD.sh),
# jamais juste affiche. OUT_COND=TFJ_CRM_TERMINE (REEL, remis a zero par
# montee_au_plan.sh le cycle suivant, jamais par ce job lui-meme).
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

SND_DIR="$OPERATIONS_DIR/cr/snd"
mkdir -p "$SND_DIR"

RAPPORT="$SND_DIR/relance_pistes_$(date +%Y%m%d).csv"

RESULTAT="$(_odoo_shell_exec "
import csv
from datetime import datetime, timedelta
Lead = env['crm.lead']
seuil = datetime.now() - timedelta(days=7)
pistes = Lead.search([('type', '=', 'lead'), ('active', '=', True), ('write_date', '<', seuil)])
with open('${RAPPORT}', 'w', newline='', encoding='utf-8') as fh:
    writer = csv.writer(fh)
    writer.writerow(['piste_ref', 'contact', 'jours_sans_activite'])
    for p in pistes:
        jours = (datetime.now() - p.write_date).days
        writer.writerow([p.name, p.partner_name or p.contact_name or '(inconnu)', jours])
print('RESULTAT:', len(pistes))
")"
COUNT="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
if [ -z "${COUNT:-}" ]; then
  echo "[ECF_CRM_CYC_RELANCE] ERREUR : execution odoo shell sans RESULTAT exploitable." >&2
  exit 1
fi

echo "[ECF_CRM_CYC_RELANCE] $COUNT piste(s) stagnante(s) depuis plus de 7 jours - rapport : $RAPPORT"
echo "$RAPPORT" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
echo "[ECF_CRM_CYC_RELANCE] Cycle TFJ CRM TERMINE pour aujourd'hui."
exit 0
