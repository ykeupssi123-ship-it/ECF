#!/bin/bash
# bin/require_confirm.sh - Pose une exigence d'approbation manuelle
# prealable (CONFIRM) sur un job, ajoute le 2026-09-01. Typiquement pose
# a l'avance sur un job dont l'effet est irreversible ou sensible (ex :
# envoi reel d'une facture par email a un client) - l'orchestrateur
# sautera ce job, meme pret, jusqu'a ./bin/confirm_job.sh. Voir
# lib/commun.sh (job_needs_confirm) et bin/confirm_job.sh.
#
# Usage :
#   ./bin/require_confirm.sh <JOB_ID> "<raison>"
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export VARS_FILE="${VARS_FILE:-$HERE/vars.conf}"
source "$VARS_FILE"
source "$HERE/lib/commun.sh"

JOB_ID="${1:-}"
RAISON="${2:-}"
if [ -z "$JOB_ID" ] || [ -z "$RAISON" ]; then
  echo "Usage : ./bin/require_confirm.sh <JOB_ID> \"<raison>\""
  exit 1
fi

if ! grep -q "^$JOB_ID," "$HERE/jobs_table.csv"; then
  echo "ERREUR : $JOB_ID introuvable dans jobs_table.csv."
  exit 1
fi

mkdir -p "$STATE_DIR/CONFIRM_REQUIS"
OPERATEUR="$(whoami)@$(hostname 2>/dev/null || echo host-inconnu)"
RAISON_SAFE="${RAISON//,/;}"
{
  echo "TIMESTAMP=$(date -Iseconds)"
  echo "OPERATEUR=$OPERATEUR"
  echo "RAISON=$RAISON_SAFE"
} > "$STATE_DIR/CONFIRM_REQUIS/${JOB_ID}.confirm"

echo "$JOB_ID exige desormais une CONFIRMATION avant execution (pose par $OPERATEUR)."
echo "Raison : $RAISON_SAFE"
echo "L'orchestrateur sautera ce job tant qu'il n'est pas approuve. Pour l'approuver : ./bin/confirm_job.sh $JOB_ID \"<raison>\""
