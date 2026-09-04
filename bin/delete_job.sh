#!/bin/bash
# bin/delete_job.sh - Suppression (DELETE) d'un job du plan d'execution
# courant, ajoute le 2026-09-01. Equivalent fonctionnel du "Delete"
# Control-M : retire le job du radar operationnel courant - distinct de
# bin/hold_job.sh (HELD reste visible comme "en attente, gele" ; DELETED
# n'apparait meme plus comme "en attente" dans bin/monitoring.sh).
#
# Usage :
#   ./bin/delete_job.sh <JOB_ID> "<raison>"
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VARS_FILE="${VARS_FILE:-$HERE/vars.conf}"
source "$VARS_FILE"
source "$HERE/lib/commun.sh"

JOB_ID="${1:-}"
RAISON="${2:-}"
if [ -z "$JOB_ID" ] || [ -z "$RAISON" ]; then
  echo "Usage : ./bin/delete_job.sh <JOB_ID> \"<raison>\""
  echo "La raison est obligatoire (audit - on ne supprime jamais un job sans dire pourquoi)."
  exit 1
fi

if ! grep -q "^$JOB_ID," "$HERE/jobs_table.csv"; then
  echo "ERREUR : $JOB_ID introuvable dans jobs_table.csv."
  exit 1
fi

mkdir -p "$STATE_DIR/DELETED"
OPERATEUR="$(whoami)@$(hostname 2>/dev/null || echo host-inconnu)"
RAISON_SAFE="${RAISON//,/;}"
{
  echo "TIMESTAMP=$(date -Iseconds)"
  echo "OPERATEUR=$OPERATEUR"
  echo "RAISON=$RAISON_SAFE"
} > "$STATE_DIR/DELETED/${JOB_ID}.deleted"

echo "$JOB_ID SUPPRIME (DELETE) par $OPERATEUR."
echo "Raison : $RAISON_SAFE"
echo "Retire du plan d'execution courant - ne sera plus tente ni liste comme"
echo "\"en attente\" tant qu'il reste supprime. Pour le restaurer : ./bin/undelete_job.sh $JOB_ID"
