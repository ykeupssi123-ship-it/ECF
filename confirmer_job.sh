#!/bin/bash
# confirmer_job.sh - "Confirm" : approuve manuellement un job pose sous
# exigence de confirmation (voir exiger_confirmation.sh), ajoute le
# 2026-09-01. Leve l'exigence puis, si le job est deja pret (dependances
# satisfaites), le lance immediatement - sinon il partira normalement des
# que pret, via ./orchestrator.sh.
#
# Usage :
#   ./confirmer_job.sh <JOB_ID> "<raison>"
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VARS_FILE="${VARS_FILE:-$HERE/vars.conf}"
source "$VARS_FILE"
source "$HERE/lib/commun.sh"

JOB_ID="${1:-}"
RAISON="${2:-}"
if [ -z "$JOB_ID" ] || [ -z "$RAISON" ]; then
  echo "Usage : ./confirmer_job.sh <JOB_ID> \"<raison>\""
  echo "La raison est obligatoire (audit - on n'approuve jamais un job sans dire pourquoi)."
  exit 1
fi
RAISON_SAFE="${RAISON//,/;}"

if ! job_needs_confirm "$JOB_ID"; then
  echo "$JOB_ID n'exige aucune confirmation actuellement. Rien a faire."
  echo "(Pour en poser une : ./exiger_confirmation.sh $JOB_ID \"<raison>\")"
  exit 0
fi

echo "Exigence de confirmation actuelle :"
cat "$STATE_DIR/CONFIRM_REQUIS/${JOB_ID}.confirm"
echo ""

OPERATEUR="$(whoami)@$(hostname 2>/dev/null || echo host-inconnu)"
read -r -p "Tapez exactement '$JOB_ID' pour confirmer et approuver : " CONFIRM
if [ "$CONFIRM" != "$JOB_ID" ]; then
  echo "Confirmation incorrecte. Rien n'a ete approuve."
  exit 1
fi

rm -f "$STATE_DIR/CONFIRM_REQUIS/${JOB_ID}.confirm"
echo "$JOB_ID CONFIRME (approuve) par $OPERATEUR le $(date -Iseconds)."
echo "Raison : $RAISON_SAFE"

JOBS_CSV="$HERE/jobs_table.csv"
LINE=""
while IFS=',' read -r C_JOB_ID C_JOB_NAME C_JOB_ROLE C_COMPONENT C_SCRIPT_FILE C_DESC C_IN_COND C_OUT_COND C_SERVICE; do
  [ "$C_JOB_ID" = "$JOB_ID" ] && { LINE=1; break; }
done < "$JOBS_CSV"

MISSING=""
if [ -n "${C_IN_COND:-}" ] && [ "$C_IN_COND" != "NONE" ]; then
  IFS='|' read -ra deps <<< "$C_IN_COND"
  for d in "${deps[@]}"; do
    job_done "$d" || MISSING="${MISSING}${MISSING:+, }$d"
  done
fi

if [ -n "$LINE" ] && [ -z "$MISSING" ] && ! job_done "${C_OUT_COND:-}"; then
  echo "Toutes ses dependances sont satisfaites - lancement immediat..."
  exec "$HERE/executer_maintenant.sh" "$JOB_ID"
fi

echo "Il partira normalement au prochain ./orchestrator.sh des que ses dependances seront satisfaites."
