#!/bin/bash
# ECFRCRMV - ECF_CRM_RUN_MOVESTAGE - Job metier Tier 1 (voir ECFRCRCL
# pour le patron de reference complet, docs/CONVENTION_NOMMAGE.md).
# Fait avancer une opportunite existante dans le pipeline (change son
# stage). OUT_COND=NONE (repetable).
#
# Contrat de fichier : CSV avec l'en-tete exact "opportunity_name,stage"
# - nom de l'opportunite + nom exact du stage cible. Auto-routage par
# en-tete, distinct des autres jobs CRM partageant le meme dossier rcv/.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

OPERATIONS_DIR="${ODOO_HOME}/operations"
RCV_DIR="$OPERATIONS_DIR/cr/rcv"
ARC_DIR="$OPERATIONS_DIR/cr/arc"
EXPECTED_HEADER="opportunity_name,stage"

mkdir -p "$RCV_DIR" "$ARC_DIR"

shopt -s nullglob
FILES=("$RCV_DIR"/*.csv)
shopt -u nullglob

TRAITES=0
TOTAL_DEPLACEES=0
for f in "${FILES[@]}"; do
  ACTUAL_HEADER="$(head -n1 "$f" | tr -d '\r')"
  [ "$ACTUAL_HEADER" = "$EXPECTED_HEADER" ] || continue
  echo "[ECF_CRM_RUN_MOVESTAGE] Fichier reconnu : $f"

  RESULTAT="$(_odoo_shell_exec "
import csv
Lead = env['crm.lead']
Stage = env['crm.stage']
deplacees = 0
with open('${f}', newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        if not row.get('opportunity_name') or not row.get('stage'):
            continue
        lead = Lead.search([('name', '=', row['opportunity_name'])], limit=1)
        stage = Stage.search([('name', '=', row['stage'])], limit=1)
        if lead and stage:
            lead.write({'stage_id': stage.id})
            deplacees += 1
env.cr.commit()
print('RESULTAT:', deplacees)
")"
  DEPLACEES="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
  if [ -z "${DEPLACEES:-}" ]; then
    echo "[ECF_CRM_RUN_MOVESTAGE] ERREUR : execution odoo shell sans RESULTAT exploitable pour $f." >&2
    exit 1
  fi
  echo "[ECF_CRM_RUN_MOVESTAGE] $DEPLACEES opportunite(s) deplacee(s) depuis $f."
  TOTAL_DEPLACEES=$((TOTAL_DEPLACEES + DEPLACEES))
  TRAITES=$((TRAITES + 1))

  DEST="$ARC_DIR/$(date +%Y%m%d_%H%M%S)_$(basename "$f")"
  mv "$f" "$DEST"
  echo "$DEST" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
done

if [ $TRAITES -eq 0 ]; then
  echo "[ECF_CRM_RUN_MOVESTAGE] Rien a traiter dans $RCV_DIR (aucun fichier avec l'en-tete '$EXPECTED_HEADER')."
  exit 0
fi

echo "[ECF_CRM_RUN_MOVESTAGE] OK (${TRAITES} fichier(s) traite(s), ${TOTAL_DEPLACEES} opportunite(s) deplacee(s) au total)."
exit 0
