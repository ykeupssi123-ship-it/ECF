#!/bin/bash
# rejouer_job.sh - "Rerun" : relance une NOUVELLE instance d'un job deja
# execute (efface sa condition de sortie puis le rejoue), ajoute le
# 2026-09-01. Toujours respecte ses dependances reelles (contrairement a
# forcer_job.sh) - reserve a "je veux une execution fraiche de ce meme
# job", pas a un court-circuit de dependances.
#
# Usage :
#   ./rejouer_job.sh <JOB_ID> "<raison>"
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export VARS_FILE="${VARS_FILE:-$HERE/vars.conf}"
source "$VARS_FILE"
source "$HERE/lib/commun.sh"

JOB_ID="${1:-}"
RAISON="${2:-}"
if [ -z "$JOB_ID" ] || [ -z "$RAISON" ]; then
  echo "Usage : ./rejouer_job.sh <JOB_ID> \"<raison>\""
  echo "La raison est obligatoire (audit - on ne rejoue jamais un job sans dire pourquoi)."
  exit 1
fi
RAISON_SAFE="${RAISON//,/;}"

JOBS_CSV="$HERE/jobs_table.csv"
HISTORY_DIR="$STATE_DIR/history"
HISTORY_LEDGER="$STATE_DIR/JOBS_HISTORY.csv"
RUNNING_DIR="$STATE_DIR/RUNNING"
mkdir -p "$HISTORY_DIR" "$RUNNING_DIR" "$WORK_TMP_DIR"
[ -f "$HISTORY_LEDGER" ] || echo "TIMESTAMP,JOB_ID,JOB_NAME,RESULT,LOG_FILE" > "$HISTORY_LEDGER"

LINE=""
while IFS=',' read -r C_JOB_ID C_JOB_NAME C_JOB_ROLE C_COMPONENT C_SCRIPT_FILE C_DESC C_IN_COND C_OUT_COND; do
  [ "$C_JOB_ID" = "$JOB_ID" ] && { LINE=1; break; }
done < "$JOBS_CSV"

if [ -z "$LINE" ]; then
  echo "ERREUR : $JOB_ID introuvable dans jobs_table.csv."
  exit 1
fi

if job_held "$JOB_ID"; then
  echo "ERREUR : $JOB_ID est GELE (HELD). Liberez-le d'abord : ./liberer_job.sh $JOB_ID"
  exit 1
fi
if job_deleted "$JOB_ID"; then
  echo "ERREUR : $JOB_ID est SUPPRIME (DELETE). Restaurez-le d'abord : ./restaurer_job.sh $JOB_ID"
  exit 1
fi

MISSING=""
if [ -n "$C_IN_COND" ] && [ "$C_IN_COND" != "NONE" ]; then
  IFS='|' read -ra deps <<< "$C_IN_COND"
  for d in "${deps[@]}"; do
    job_done "$d" || MISSING="${MISSING}${MISSING:+, }$d"
  done
fi
if [ -n "$MISSING" ]; then
  echo "ERREUR : $JOB_ID ne peut pas etre rejoue - dependance(s) non satisfaite(s) : $MISSING"
  echo "(\"Rerun\" respecte toujours les dependances reelles. Pour outrepasser : ./forcer_job.sh $JOB_ID \"<raison>\")"
  exit 1
fi

SCRIPT_PATH="$HERE/jobs/$C_SCRIPT_FILE"
if [ ! -f "$SCRIPT_PATH" ]; then
  echo "ERREUR : script $SCRIPT_PATH introuvable."
  exit 1
fi

echo "=================================================="
echo " RERUN - $JOB_ID ($C_JOB_NAME)"
echo "=================================================="
echo "$C_DESC"
echo ""
echo "Ceci efface la condition de sortie actuelle ($C_OUT_COND) et lance"
echo "une NOUVELLE execution reelle du job."
echo ""
read -r -p "Tapez exactement '$JOB_ID' pour confirmer le rerun : " CONFIRM
if [ "$CONFIRM" != "$JOB_ID" ]; then
  echo "Confirmation incorrecte. Rerun annule, rien n'a ete execute."
  exit 1
fi

rm -f "${STATE_DIR}/${C_OUT_COND}.ok"

OPERATEUR="$(whoami)@$(hostname 2>/dev/null || echo host-inconnu)"
JOB_TS=$(date +%Y%m%d_%H%M%S_%N)
mkdir -p "$HISTORY_DIR/$JOB_ID"
JOB_LOG="$HISTORY_DIR/$JOB_ID/${JOB_TS}.log"
{
  echo "=== RERUN (nouvelle instance manuelle) ==="
  echo "Operateur   : $OPERATEUR"
  echo "Date/heure  : $(date -Iseconds)"
  echo "Raison      : $RAISON_SAFE"
  echo "=== Sortie reelle du job ==="
} > "$JOB_LOG"

JOB_START_EPOCH=$(date +%s)
bash "$SCRIPT_PATH" >> "$JOB_LOG" 2>&1 < /dev/null &
JOB_PID=$!
echo "$(date -Iseconds),$JOB_PID,$C_JOB_NAME (RERUN)" > "$RUNNING_DIR/${JOB_ID}.running"
wait "$JOB_PID"
JOB_EXIT=$?
rm -f "$RUNNING_DIR/${JOB_ID}.running"
JOB_DURATION_SEC=$(( $(date +%s) - JOB_START_EPOCH ))

echo "--- Sortie de $JOB_ID ---"
cat "$JOB_LOG"
echo "--- Fin de sortie ---"

if [ $JOB_EXIT -eq 0 ]; then
  mark_done "$C_OUT_COND"
  echo "$(date -Iseconds),$JOB_ID,$C_JOB_NAME,REJOUE_OK,$JOB_LOG,$JOB_DURATION_SEC" >> "$HISTORY_LEDGER"
  echo "$JOB_ID -> REJOUE_OK ($C_OUT_COND)."
  exit 0
else
  echo "$(date -Iseconds),$JOB_ID,$C_JOB_NAME,REJOUE_ECHEC,$JOB_LOG,$JOB_DURATION_SEC" >> "$HISTORY_LEDGER"
  echo "$JOB_ID -> REJOUE_ECHEC. Voir $JOB_LOG."
  exit 1
fi
