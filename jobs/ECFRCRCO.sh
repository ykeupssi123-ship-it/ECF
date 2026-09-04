#!/bin/bash
# ECFRCRCO - ECF_CRM_RUN_CONVERTOPP - Job metier Tier 1 (voir ECFRCRCL
# pour le patron de reference complet, docs/CONVENTION_NOMMAGE.md).
# Convertit une piste (type=lead) existante en opportunite
# (type=opportunity). OUT_COND=NONE (repetable).
#
# Contrat de fichier : CSV avec l'en-tete exact "lead_name" - un nom de
# piste par ligne. Auto-routage par en-tete (voir docs/CONVENTION_NOMMAGE.md,
# "Validation d'en-tete") : un fichier dont l'en-tete ne correspond pas
# est ignore par CE job (peut appartenir a un autre job CRM partageant
# le meme dossier rcv), jamais traite a l'aveugle. En-tete distinct de
# celui de ECFRCRWO (MARKWON) volontairement - deux jobs partageant le
# meme dossier rcv/ ne doivent jamais pouvoir revendiquer le meme
# fichier (defaut trouve et corrige le 4 septembre 2026, les deux
# jobs partageaient d'abord l'en-tete "name").
set -uo pipefail
source "$VARS_FILE"
PROJECT_ROOT="$(dirname "$VARS_FILE")"
source "$PROJECT_ROOT/lib/commun.sh"

OPERATIONS_DIR="${ODOO_HOME}/operations"
RCV_DIR="$OPERATIONS_DIR/cr/rcv"
ARC_DIR="$OPERATIONS_DIR/cr/arc"
EXPECTED_HEADER="lead_name"

mkdir -p "$RCV_DIR" "$ARC_DIR"

shopt -s nullglob
FILES=("$RCV_DIR"/*.csv)
shopt -u nullglob

TRAITES=0
TOTAL_CONVERTIES=0
for f in "${FILES[@]}"; do
  ACTUAL_HEADER="$(head -n1 "$f" | tr -d '\r')"
  [ "$ACTUAL_HEADER" = "$EXPECTED_HEADER" ] || continue
  echo "[ECF_CRM_RUN_CONVERTOPP] Fichier reconnu : $f"

  RESULTAT="$(_odoo_shell_exec "
import csv
Lead = env['crm.lead']
converties = 0
with open('${f}', newline='', encoding='utf-8') as fh:
    reader = csv.DictReader(fh)
    for row in reader:
        if not row.get('lead_name'):
            continue
        lead = Lead.search([('name', '=', row['lead_name']), ('type', '=', 'lead')], limit=1)
        if lead:
            lead.write({'type': 'opportunity'})
            converties += 1
env.cr.commit()
print('RESULTAT:', converties)
")"
  CONVERTIES="$(echo "$RESULTAT" | grep -o 'RESULTAT:.*' | awk '{print $2}')"
  if [ -z "${CONVERTIES:-}" ]; then
    echo "[ECF_CRM_RUN_CONVERTOPP] ERREUR : execution odoo shell sans RESULTAT exploitable pour $f." >&2
    exit 1
  fi
  echo "[ECF_CRM_RUN_CONVERTOPP] $CONVERTIES piste(s) convertie(s) depuis $f."
  TOTAL_CONVERTIES=$((TOTAL_CONVERTIES + CONVERTIES))
  TRAITES=$((TRAITES + 1))

  DEST="$ARC_DIR/$(date +%Y%m%d_%H%M%S)_$(basename "$f")"
  mv "$f" "$DEST"
  echo "$DEST" >> "${ECF_JOB_PATHS_FILE:-/dev/null}"
done

if [ $TRAITES -eq 0 ]; then
  echo "[ECF_CRM_RUN_CONVERTOPP] Rien a traiter dans $RCV_DIR (aucun fichier avec l'en-tete '$EXPECTED_HEADER')."
  exit 0
fi

echo "[ECF_CRM_RUN_CONVERTOPP] OK (${TRAITES} fichier(s) traite(s), ${TOTAL_CONVERTIES} piste(s) convertie(s) au total)."
exit 0
