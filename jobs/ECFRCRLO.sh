#!/bin/bash
# ECFRCRLO - ECF_CRM_RUN_MARKLOST - Job metier Tier 1 (voir ECFRCRCL
# pour le patron de reference complet, docs/CONVENTION_NOMMAGE.md).
# Marque une opportunite existante comme perdue, avec motif
# (active=False, probability=0, lost_reason_id). OUT_COND=NONE
# (repetable).
#
# Contrat de fichier : CSV avec l'en-tete exact
# "opportunity_name,lost_reason" - nom de l'opportunite + motif texte
# libre (cree en base s'il n'existe pas encore, jamais une liste fermee
# a maintenir a la main). Auto-routage par en-tete, distinct des autres
# jobs CRM partageant le meme dossier rcv/.
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

RCV_DIR="$OPERATIONS_DIR/cr/rcv"
ARC_DIR="$OPERATIONS_DIR/cr/arc"
EXPECTED_HEADER="opportunity_name,lost_reason"

mkdir -p "$RCV_DIR" "$ARC_DIR"

shopt -s nullglob
FILES=("$RCV_DIR"/*.csv)
shopt -u nullglob

TRAITES=0
TOTAL_PERDUES=0
for f in "${FILES[@]}"; do
  ACTUAL_HEADER="$(head -n1 "$f" | tr -d '\r')"
  [ "$ACTUAL_HEADER" = "$EXPECTED_HEADER" ] || continue
  echo "[ECF_CRM_RUN_MARKLOST] Fichier reconnu : $f"

  RESULTAT="$(_odoo_shell_exec "
import csv
Lead = env['crm.lead']
Reason = env['crm.lost.reason']
perdues = 0
with open('${f}', newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        if not row.get('opportunity_name'):
            continue
        lead = Lead.search([('name', '=', row['opportunity_name'])], limit=1)
        if not lead:
            continue
        reason_id = False
        if row.get('lost_reason'):
            reason = Reason.search([('name', '=', row['lost_reason'])], limit=1)
            if not reason:
                reason = Reason.create({'name': row['lost_reason']})
            reason_id = reason.id
        lead.write({'active': False, 'probability': 0, 'lost_reason_id': reason_id})
        perdues += 1
env.cr.commit()
print('RESULTAT:', perdues)
")"
  PERDUES="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
  if [ -z "${PERDUES:-}" ]; then
    echo "[ECF_CRM_RUN_MARKLOST] ERREUR : execution odoo shell sans RESULTAT exploitable pour $f." >&2
    exit 1
  fi
  echo "[ECF_CRM_RUN_MARKLOST] $PERDUES opportunite(s) marquee(s) perdue(s) depuis $f."
  TOTAL_PERDUES=$((TOTAL_PERDUES + PERDUES))
  TRAITES=$((TRAITES + 1))

  DEST="$ARC_DIR/$(date +%Y%m%d_%H%M%S)_$(basename "$f")"
  mv "$f" "$DEST"
  echo "$DEST" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
done

if [ $TRAITES -eq 0 ]; then
  echo "[ECF_CRM_RUN_MARKLOST] Rien a traiter dans $RCV_DIR (aucun fichier avec l'en-tete '$EXPECTED_HEADER')."
  exit 0
fi

echo "[ECF_CRM_RUN_MARKLOST] OK (${TRAITES} fichier(s) traite(s), ${TOTAL_PERDUES} opportunite(s) perdue(s) au total)."
exit 0
