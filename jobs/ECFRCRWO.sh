#!/bin/bash
# ECFRCRWO - ECF_CRM_RUN_MARKWON - Job metier Tier 1 (voir ECFRCRCL
# pour le patron de reference complet, docs/CONVENTION_NOMMAGE.md).
# Marque une opportunite existante comme gagnee (stage is_won=True,
# probability=100). OUT_COND=NONE (repetable).
#
# Contrat de fichier : CSV avec l'en-tete exact "opportunity_name" - un
# nom d'opportunite par ligne. Auto-routage par en-tete, distinct des
# autres jobs CRM partageant le meme dossier rcv/ (defaut trouve et
# corrige le 4 septembre 2026 : ce job et ECFRCRCO/CONVERTOPP
# partageaient d'abord tous deux l'en-tete "name").
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

OPERATIONS_DIR="${ODOO_HOME}/operations"
RCV_DIR="$OPERATIONS_DIR/cr/rcv"
ARC_DIR="$OPERATIONS_DIR/cr/arc"
EXPECTED_HEADER="opportunity_name"

mkdir -p "$RCV_DIR" "$ARC_DIR"

shopt -s nullglob
FILES=("$RCV_DIR"/*.csv)
shopt -u nullglob

TRAITES=0
TOTAL_GAGNEES=0
for f in "${FILES[@]}"; do
  ACTUAL_HEADER="$(head -n1 "$f" | tr -d '\r')"
  [ "$ACTUAL_HEADER" = "$EXPECTED_HEADER" ] || continue
  echo "[ECF_CRM_RUN_MARKWON] Fichier reconnu : $f"

  RESULTAT="$(_odoo_shell_exec "
import csv
Lead = env['crm.lead']
Stage = env['crm.stage']
stage_won = Stage.search([('is_won', '=', True)], limit=1)
assert stage_won, 'aucun stage is_won=True trouve dans le pipeline CRM'
gagnees = 0
with open('${f}', newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        if not row.get('opportunity_name'):
            continue
        lead = Lead.search([('name', '=', row['opportunity_name'])], limit=1)
        if lead:
            lead.write({'stage_id': stage_won.id, 'probability': 100})
            gagnees += 1
env.cr.commit()
print('RESULTAT:', gagnees)
")"
  GAGNEES="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
  if [ -z "${GAGNEES:-}" ]; then
    echo "[ECF_CRM_RUN_MARKWON] ERREUR : execution odoo shell sans RESULTAT exploitable pour $f." >&2
    exit 1
  fi
  echo "[ECF_CRM_RUN_MARKWON] $GAGNEES opportunite(s) marquee(s) gagnee(s) depuis $f."
  TOTAL_GAGNEES=$((TOTAL_GAGNEES + GAGNEES))
  TRAITES=$((TRAITES + 1))

  DEST="$ARC_DIR/$(date +%Y%m%d_%H%M%S)_$(basename "$f")"
  mv "$f" "$DEST"
  echo "$DEST" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
done

if [ $TRAITES -eq 0 ]; then
  echo "[ECF_CRM_RUN_MARKWON] Rien a traiter dans $RCV_DIR (aucun fichier avec l'en-tete '$EXPECTED_HEADER')."
  exit 0
fi

echo "[ECF_CRM_RUN_MARKWON] OK (${TRAITES} fichier(s) traite(s), ${TOTAL_GAGNEES} opportunite(s) gagnee(s) au total)."
exit 0
